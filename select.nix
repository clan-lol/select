rec {
  /**
      parseSelector :: String -> [ Selector ]

      Example:
      parseSelector ''*.{foo,bla,?bob}.123.hello.?bla''
      => [
        { type = "all"; }
        { type = "set" value = [
          { type = str; value = "foo"; }
          { type = str; value = "bla"; }
          { type = maybe; value = "bob"; }
        ]; }
        { type = "str" value = "123"; }
        { type = "str" value = "hello"; }
        { type = "maybe"; value = "bla"; }
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
          # we only need to handle str and maybe here because other modes have a terminating character
          if (mode == "str") || (mode == "maybe") then
            state.selectors
            ++ [
              {
                type = mode;
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

          else if cur == "?" then
            recurse str (idx + 1) (
              state
              // {
                stack = [ "maybe" ] ++ state.stack;
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
          else if cur == "." then
            recurse str (idx + 1) (
              state
              // {
                selectors = state.selectors ++ [ { type = "str"; value = state.acc_str; } ];
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

        # a set selector {foo,bar}
        else if mode == "set" then
          if (state.submode == "") && (cur == "?") then
            recurse str (idx + 1) (
              state
              // {
                submode = "maybe";
              }
            )
          else if cur == "\\" then
            recurse str (idx + 1) (
              state
              // {
                stack = [
                  "escape"
                ] ++ state.stack;
                submode = if state.submode == "" then "str" else state.submode;
              }
            )
          else if cur == ''"'' then
            recurse str (idx + 1) (
              state
              // {
                stack = [
                  "quote"
                ] ++ state.stack;
                submode = if state.submode == "" then "str" else state.submode;
              }
            )
          else if cur == "," then
            recurse str (idx + 1) (
              state
              // {
                acc_selectors = state.acc_selectors ++ [
                  {
                    type = if state.submode == "" then "str" else state.submode;
                    value = state.acc_str;
                  }
                ];
                submode = "";
                acc_str = "";
              }
            )
          else if cur == "}" then
            recurse str (idx + 1) (
              state
              // {
                stack = [ "end" ] ++ (builtins.tail state.stack);
                selectors = state.selectors ++ [
                  {
                    type = "set";
                    value = state.acc_selectors ++ [
                      {
                        type = if state.submode == "" then str else state.submode;
                        value = state.acc_str;
                      }
                    ];
                  }
                ];
                submode = "";
                acc_selectors = [ ];
              }
            )
          else
            recurse str (idx + 1) (
              state
              // {
                acc_str = "${state.acc_str}${cur}";
                submode = if state.submode == "" then "str" else state.submode;
              }
            )

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

        # just a normal string selector or maybe
        else if (mode == "str") || (mode == "maybe") then
          if cur == "." then
            if builtins.length state.stack > 1 then
              throw "stack unexpected length ${state.stack}"
            else
              recurse str (idx + 1) (
                state
                // {
                  stack = builtins.tail state.stack;
                  acc_str = "";
                  selectors = state.selectors ++ [
                    {
                      type = mode;
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
      submode = ""; # only used by set
      acc_selectors = [ ]; # only used by set
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
              let
                listSelectors = builtins.map (
                  x:
                  if x.type == "str" then
                    toInt x.value
                  else if x.type == "maybe" then
                    throw "maybe type not supported for lists in set"
                  else
                    throw "unexpected type ${x.type}"
                ) selector.value;
              in
              builtins.map (i: recurse selectors (idx + 1) (builtins.elemAt obj i)) listSelectors
            else if selector.type == "maybe" then
              if (builtins.length obj) > (toInt selector.value) then
                [ (recurse selectors (idx + 1) (builtins.elemAt obj (toInt selector.value))) ]
              else
                [ ]
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
                attrsAvailable = builtins.filter (
                  x: (x.type == "str") || (builtins.hasAttr x.value obj)
                ) selector.value;
                filteredAttrs = builtins.listToAttrs (
                  map (x: {
                    name = x.value;
                    value = builtins.getAttr x.value obj;
                  }) attrsAvailable
                );
              in
              builtins.mapAttrs (_: v: recurse selectors (idx + 1) v) filteredAttrs
            else if selector.type == "maybe" then
              if builtins.hasAttr selector.value obj then
                { ${selector.value} = recurse selectors (idx + 1) (builtins.getAttr selector.value obj); }
              else
                { }
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
