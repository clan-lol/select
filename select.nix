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
    parseSelector :: str -> [str]

    # Inputs

    `selector`

    : 1\. Specialised attribute path string.

    # Examples
    :::{.example}

    ```nix
    parseSelector "foo.bar"
    => [ "foo" "bar" ]
    parseSelector ''someAttrset."foo.bar"''
    => [ "someAttrset" "foo.bar" ]
    parseSelector ''someAttrset.{"foo.bar","foo.baz"}''
    => [ "someAttrset" "{foo.bar,foo.baz}" ]
    ```
  **/
  parseSelector =
    let
      # alternate :: [str] -> (str -> [str]) -> (str -> [str]) -> Int -> [str]
      # Example:
      #  alternate [ 1 2 ] (x: [ (x + 1) ]) (x: [ (x + 2) ]) 0 == [ 2 4 ]
      alternate = list: f: g:
        let
          len = builtins.length list;
          go = idx: f: g:
            if idx >= len then [ ] else f (builtins.elemAt list idx) ++ go (idx + 1) g f;
        in go 0 f g;
      # parseQuoted :: str -> [str]
      # A selector parser that supports quoted strings.
      parseQuoted = s:
        alternate
          # A list of strings separated by quotes
          (builtins.filter (x: !builtins.isList x) (builtins.split ''"'' s))
          # Split the string by dots
          (x: builtins.filter (x: x != "") (
                map (builtins.replaceStrings [ "." ] [ "" ])
                  (builtins.filter (x: !builtins.isList x) (builtins.split ''\.'' x))))
          (x: [ x ]);
      splitByCurly = x: builtins.filter (x: !builtins.isList x) (builtins.split ''[{}]'' x);
    in
      selector:
        alternate (splitByCurly selector)
          parseQuoted
          # `parseQuoted` the string inside the curly braces
          (x: [ ("{" + builtins.concatStringsSep "" (parseQuoted x) + "}") ]);

  select = selector: target: recursiveSelect 0 (parseSelector selector) target;
}
