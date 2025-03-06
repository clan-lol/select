rec {
  recursiveSelect =
    selectorIndex: selectorList: target:
    let
      selector = builtins.elemAt selectorList selectorIndex;
    in

    # selector is empty, we are done
    if selectorIndex + 1 > builtins.length selectorList then
      target

    else if builtins.isList target then
      # support bla.* for lists and recurse into all elements
      if selector == "*" then
        builtins.map (v: recursiveSelect (selectorIndex + 1) selectorList v) target
      # support bla.3 for lists and recurse into the 4th element
      else if (builtins.match "[[:digit:]]*" selector) == [ ] then
        recursiveSelect (selectorIndex + 1) selectorList (
          builtins.elemAt target (builtins.fromJSON selector)
        )
      # support bla.{1,3} for lists and recurse into the second and fourth elements
      else if (builtins.match ''^\{([^}]*)}$'' selector) != null then
        let
          elementsToGet = map builtins.fromJSON (
            builtins.filter (x: !builtins.isList x) (
              builtins.split "," (builtins.head (builtins.match ''^\{([^}]*)}$'' selector))
            )
          );
        in map (i: recursiveSelect (selectorIndex + 1) selectorList (builtins.elemAt target i)) elementsToGet
      else
        throw "only *, {n,n} or a number is allowed in list selector"

    else if builtins.isAttrs target then
      # handle the case bla.x.*.z where x is an attrset and we recurse into all elements
      if selector == "*" then
        builtins.mapAttrs (_: v: recursiveSelect (selectorIndex + 1) selectorList v) target
      # support bla.{x,y,z}.world where we get world from each of x, y and z
      else if (builtins.match ''^\{([^}]*)}$'' selector) != null then
        let
          attrsAsList = (
            builtins.filter (x: !builtins.isList x) (
              builtins.split "," (builtins.head (builtins.match ''^\{([^}]*)}$'' selector))
            )
          );
          dummyAttrSet = builtins.listToAttrs (
            map (x: {
              name = x;
              value = null;
            }) attrsAsList
          );
          filteredAttrs = builtins.intersectAttrs dummyAttrSet target;
        in
        builtins.mapAttrs (_: v: recursiveSelect (selectorIndex + 1) selectorList v) filteredAttrs
      else
        recursiveSelect (selectorIndex + 1) selectorList (builtins.getAttr selector target)
    else
      throw "Expected a list or an attrset";

  /**
    Selector parser that supports parsing quoted attributes.

    parseQuotedSelector :: str -> [str]

    # Inputs

    `x`

    : 1\. Selector string (Specialised attribute path)

    # Examples
    :::{.example}

    ```nix
    parseQuotedSelector "foo.bar"
    => [ "foo" "bar" ]
    parseQuotedSelector ''someAttrset."foo.bar"''
    => [ "someAttrset" "foo.bar" ]

    ```
  **/
  parseQuotedSelector =
    let
      splitByQuote = x: builtins.filter (x: !builtins.isList x) (builtins.split ''"'' x);
      splitByDot =
        x:
        builtins.filter (x: x != "") (
          map (builtins.replaceStrings [ "." ] [ "" ]) (
            builtins.filter (x: !builtins.isList x) (builtins.split ''\.'' x)
          )
        );
      handleQuoted =
        x: if x == [ ] then [ ] else [ (builtins.head x) ] ++ handleUnquoted (builtins.tail x);
      handleUnquoted =
        x: if x == [ ] then [ ] else splitByDot (builtins.head x) ++ handleQuoted (builtins.tail x);
    in
      selector: handleUnquoted (splitByQuote selector);

  /**
    parseSelector :: str -> [str]

    Examples:
      parseSelector "foo.bar" == [ "foo" "bar" ]
  **/
  parseSelector =
    let
      splitByCurly = x: builtins.filter (x: !builtins.isList x) (builtins.split ''[{}]'' x);
      handleCurly = x:
        if x == [ ] then
          [ ]
        else
          [ ("{" + (builtins.concatStringsSep "" (parseQuotedSelector (builtins.head x))) + "}") ]
          ++ handleUncurly (builtins.tail x);
      handleUncurly =
        x: if x == [ ] then [ ] else (parseQuotedSelector (builtins.head x)) ++ handleCurly (builtins.tail x);
    in
      selector: handleUncurly (splitByCurly selector);

  select = selector: target: recursiveSelect 0 (parseSelector selector) target;
}
