rec {
  /**
      parseSelector :: String -> [ Selector ]

      Example:
      parseSelector ''*.{foo,bla}.123.hello''
      => [
        { type = "all"; }
        { type = "set" values = [
          { type = str; value = "foo"; }
          { type = str; value = "bla"; }
        ]; }
        { type = "str" value = "123"; }
        { type = "str" value = "hello"; }
      ]
  */
  parseSelector =
    x:
    let
      recurse =
        str: idx: state:
        let
          cur = builtins.substring idx 1 str;
          mode = if state.stack == [ ] then "start" else builtins.head state.stack;
        in
        # reached end of string
        if idx == builtins.stringLength str then
          # we only need to handle str here because other modes have a terminating character
          if mode == "str" then
            state.selectors
            ++ [
              {
                type = "str";
                value = state.acc_str;
              }
            ]
          else
            state.selectors

        # the selector ended, so we are expected to see a .
        else if mode == "end" then
          if cur == "." then
            # TODO check if stack is empty
            recurse str (idx + 1) (
              state
              // {
                stack = [ ];
                acc_str = "";
              }
            )
          else
            throw "unexpected character ${cur} expected ."

        # we are at the start of a selector
        else if mode == "start" then
          if cur == "*" then
            recurse str (idx + 1) (
              state
              // {
                stack = [ "end" ] ++ state.stack;
                selectors = state.selectors ++ [ { type = "all"; } ];
                acc_str = "";
              }
            )

          else if cur == ''"'' then
            recurse str (idx + 1) (
              state
              // {
                stack = [
                  "quote"
                  "str"
                ] ++ state.stack;
              }
            )
          else if cur == "{" then
            recurse str (idx + 1) (
              state
              // {
                stack = [ "set" ] ++ state.stack;
                acc_str = "";
              }
            )
          else if cur == "\\" then
            recurse str (idx + 1) (
              state
              // {
                stack = [
                  "escape"
                  "str"
                ] ++ state.stack;
              }
            )
          else
            recurse str (idx + 1) (
              state
              // {
                stack = [ "str" ] ++ state.stack;
                acc_str = "${state.acc_str}${cur}";
              }
            )

        # inside a set multuple values {foo,bar}
        else if mode == "set" then
          if cur == "}" then
            recurse str (idx + 1) (
              state
              // {
                stack = [ "end" ] ++ state.stack;
                selectors = state.selectors ++ [
                  {
                    type = "set";
                    values = state.acc_selectors ++ [
                      {
                        type = "str";
                        value = state.acc_str;
                      }
                    ];
                  }
                ];
                acc_str = "";
                acc_selectors = [ ];
              }
            )
          else if cur == "," then
            recurse str (idx + 1) (
              state
              // {
                acc_selectors = state.acc_selectors ++ [
                  {
                    type = "str";
                    value = state.acc_str;
                  }
                ];
                acc_str = "";
              }
            )
          else if cur == "\\" then
            recurse str (idx + 1) (state // { stack = [ "escape" ] ++ state.stack; })
          else if cur == ''"'' then
            recurse str (idx + 1) (state // { stack = [ "quote" ] ++ state.stack; })
          else
            recurse str (idx + 1) (state // { acc_str = "${state.acc_str}${cur}"; })

        # inside a quoted string "bla"
        else if mode == "quote" then
          if cur == ''"'' then
            recurse str (idx + 1) (state // { stack = builtins.tail state.stack; })
          else if cur == "\\" then
            recurse str (idx + 1) (state // { stack = [ "escape" ] ++ state.stack; })
          else
            recurse str (idx + 1) (state // { acc_str = "${state.acc_str}${cur}"; })

        # we try to escape soemthing with \
        else if mode == "escape" then
          recurse str (idx + 1) (
            state
            // {
              acc_str = "${state.acc_str}${cur}";
              stack = builtins.tail state.stack;
            }
          )

        # just a normal string selector
        else if mode == "str" then
          if cur == "." then
            if builtins.length state.stack > 1 then
              throw "stack unexpected length ${state.stack}"
            else
              recurse str (idx + 1) (
                state
                // {
                  stack = [ ];
                  acc_str = "";
                  selectors = state.selectors ++ [
                    {
                      type = "str";
                      value = state.acc_str;
                    }
                  ];
                }
              )
          else if cur == "\\" then
            recurse str (idx + 1) (state // { stack = [ "escape" ] ++ state.stack; })
          else
            recurse str (idx + 1) (state // { acc_str = "${state.acc_str}${cur}"; })

        else
          throw "unknown mode ${mode}";
    in
    recurse x 0 {
      stack = [ ];
      acc_selectors = [ ];
      acc_str = "";
      selectors = [ ];
    };

  /**
    applySelectors [ Selectors ] -> dict/list -> Any

      Example:
        applySelectors [ { type = "all"; } { type = "str"; value = "foo"; } ] { x.foo = "bar"; }
      => "bar
    *
  */
  applySelectors =
    selectors: obj:
    let
      recurse =
        selectors: idx: obj:
        # we are done
        if builtins.length selectors == idx then
          obj

        else
          let
            selector = builtins.elemAt selectors idx;
            toInt =
              str:
              let
                x = builtins.fromJSON str;
              in
              if builtins.isInt x then x else throw "cannot convert ${str} to int";
          in
          # lists
          if builtins.isList obj then
            if selector.type == "all" then
              builtins.map (item: recurse selectors (idx + 1) item) obj
            else if selector.type == "str" then
              recurse selectors (idx + 1) (builtins.elemAt obj (toInt selector.value))
            else if selector.type == "set" then
              builtins.map (i: recurse selectors (idx + 1) (builtins.elemAt obj (toInt i.value))) selector.values
            else
              throw "unexpected type ${selector.type}"

          # attrs
          else if builtins.isAttrs obj then
            if selector.type == "all" then
              builtins.mapAttrs (_: v: recurse selectors (idx + 1) v) obj
            else if selector.type == "str" then
              recurse selectors (idx + 1) (builtins.getAttr selector.value obj)
            else if selector.type == "set" then
              let
                filteredAttrs = builtins.listToAttrs (
                  map (x: {
                    name = x.value;
                    value = builtins.getAttr x.value obj;
                  }) selector.values
                );
              in
              builtins.mapAttrs (_: v: recurse selectors (idx + 1) v) filteredAttrs
            else
              throw "unexpected type ${selector.type}"
          else
            throw "unexpected type ${builtins.typeOf obj}";
    in
    recurse selectors 0 obj;

  /**
      select :: str -> dict/list -> Any

      Example:
        select "*.x.y" { a.x.y = 123; }
      =>
        { a = 123; }
    *
  */
  select = selector: obj: applySelectors (parseSelector selector) obj;
}
