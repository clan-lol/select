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

    Examples:
      parseSelector "foo.bar" == [ "foo" "bar" ]
  **/
  parseSelector =
    let
      splitByDot = x: builtins.filter (s: !builtins.isList s) (builtins.split ''\.'' x);
    in
    selector:
      builtins.concatMap (x:
        if (builtins.isString x) then (builtins.filter (s: s != "") (splitByDot x)) else x)
        # ''foo.bar."baz"'' -> [ "foo.bar" [ "baz" ] ]
        (builtins.split ''"([^"]*)"'' selector);

  select = selector: target: recursiveSelect 0 (parseSelector selector) target;
}
