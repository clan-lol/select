let
  select = (import ./select.nix).select;
  testdata = {
    somedict = {
      hello = "world";
      foo = {
        something.x = "hi";
        something.y = "there";
        something.z = "sup";
      };
      "foo.bar" = "baz";
      "foo.baz" = "bar";
      "foo,baz" = "foo";
    };
    somelists = [
      {
        name = "foo";
        data.a = ":)";
      }
      {
        name = "bar";
        data.b = ":|";
      }
      {
        name = "baz";
        data.c = ":(";
      }
    ];
  };
in
{
  listSingle =
    assert ((select "somelists.0.name" testdata) == "foo");
    true;
  listAll =
    assert (
      (select "somelists.*.name" testdata) == [
        "foo"
        "bar"
        "baz"
      ]
    );
    true;
  listMulti =
    assert (
      (select "somelists.{0,2}.name" testdata) == [
        "foo"
        "baz"
      ]
    );
    true;
  dictSingle =
    assert ((select "somedict.hello" testdata) == "world");
    true;
  dictQuoted =
    assert ((select ''somedict."foo.bar"'' testdata) == "baz");
    true;
  dictMulti =
    assert (
      (select "somedict.foo.something.{x,y}" testdata) == {
        x = "hi";
        y = "there";
      }
    );
    true;
  dictAll =
    assert (
      (select "somedict.foo.something.*" testdata) == {
        x = "hi";
        y = "there";
        z = "sup";
      }
    );
    true;
  multiQuote =
    assert (
      (select ''somedict.{"foo.bar","foo.baz"}'' testdata) == {
        "foo.bar" = "baz";
        "foo.baz" = "bar";
      }
    );
    true;
  multiQuoteWithComma =
    assert (
      (select ''somedict.{"foo.bar",foo.baz,"foo,baz"}'' testdata) == {
        "foo.bar" = "baz";
        "foo.baz" = "bar";
        "foo,baz" = "foo";
      }
    );
    true;
  multiEscape =
    assert (
      (select ''somedict.{foo\.bar,foo.baz,foo\,baz}'' testdata) == {
        "foo.bar" = "baz";
        "foo.baz" = "bar";
        "foo,baz" = "foo";
      }
    );
    true;
  maybeExist =
    assert ((select ''somedict.foo.?something.x'' testdata) == { something = "hi"; });
    true;

  maybeNotExist =
    assert ((select ''somedict.foo.?nothing.x'' testdata) == { });
    true;

  maybeListExist =
    assert ((select ''somelists.?2.data.c'' testdata) == [ ":(" ]);
    true;

  maybeListNotExist =
    assert ((select ''somelists.?3'' testdata) == [ ]);
    true;

  maybeInSet =
    assert (
      (select ''somedict.foo.something.{?x,?z,?a}'' testdata) == {
        x = "hi";
        z = "sup";
      }
    );
    true;
}
