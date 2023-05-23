defmodule Grax.Schema.InheritanceTest do
  use Grax.TestCase

  alias Grax.Schema.{Inheritance, TypeError}
  alias Grax.InvalidResourceTypeError

  alias Example.{
    User,
    ParentSchema,
    AnotherParentSchema,
    ChildSchema,
    ChildSchemaWithClass,
    ChildOfMany,
    PolymorphicLinks,
    NonPolymorphicLinks
  }

  test "__super__/0" do
    assert ChildSchema.__super__() == [ParentSchema]
    assert ChildSchemaWithClass.__super__() == [ParentSchema]

    assert ChildOfMany.__super__() == [
             ParentSchema,
             AnotherParentSchema,
             ChildSchemaWithClass
           ]

    assert ParentSchema.__super__() == nil
  end

  test "__class__/0" do
    assert ChildSchemaWithClass.__class__() == IRI.to_string(EX.Child2)
  end

  describe "field inheritance" do
    test "struct fields are inherited" do
      assert ChildSchema.build!(EX.S)
             |> Map.from_struct()
             |> Map.keys()
             |> MapSet.new() ==
               MapSet.new(~w[__id__ __additional_statements__ dp1 dp2 dp3 lp1 lp2 lp3 f1 f2 f3]a)

      assert ChildSchemaWithClass.build!(EX.S)
             |> Map.from_struct()
             |> Map.keys()
             |> MapSet.new() ==
               ParentSchema.build!(EX.S)
               |> Map.from_struct()
               |> Map.keys()
               |> MapSet.new()
               |> MapSet.put(:dp4)
    end

    test "properties are inherited" do
      assert ChildSchema.__properties__() == %{
               dp1: %Grax.Schema.DataProperty{
                 name: :dp1,
                 iri: ~I<http://example.com/dp1>,
                 schema: ChildSchema,
                 from_rdf: {ParentSchema, :upcase}
               },
               dp2: %Grax.Schema.DataProperty{
                 name: :dp2,
                 iri: ~I<http://example.com/dp22>,
                 schema: ChildSchema
               },
               dp3: %Grax.Schema.DataProperty{
                 name: :dp3,
                 iri: ~I<http://example.com/dp3>,
                 schema: ChildSchema
               },
               lp1: %Grax.Schema.LinkProperty{
                 name: :lp1,
                 iri: ~I<http://example.com/lp1>,
                 schema: ChildSchema,
                 on_rdf_type_mismatch: :ignore,
                 polymorphic: true,
                 type: {:resource, User}
               },
               lp2: %Grax.Schema.LinkProperty{
                 name: :lp2,
                 iri: ~I<http://example.com/lp22>,
                 schema: ChildSchema,
                 on_rdf_type_mismatch: :ignore,
                 polymorphic: true,
                 type: {:resource, User}
               },
               lp3: %Grax.Schema.LinkProperty{
                 name: :lp3,
                 iri: ~I<http://example.com/lp3>,
                 schema: ChildSchema,
                 on_rdf_type_mismatch: :ignore,
                 polymorphic: true,
                 type: {:resource, User}
               }
             }
    end

    test "custom fields are inherited" do
      assert ChildSchema.__custom_fields__() == %{
               f1: %Grax.Schema.CustomField{name: :f1, default: :foo},
               f2: %Grax.Schema.CustomField{name: :f2, from_rdf: {ChildSchema, :foo}},
               f3: %Grax.Schema.CustomField{name: :f3}
             }
    end

    test "multiple inheritance" do
      assert ChildOfMany.build!(EX.S)
             |> Map.from_struct()
             |> Map.keys()
             |> MapSet.new() ==
               MapSet.new(
                 ~w[__id__ __additional_statements__ dp1 dp2 dp3 dp4 lp1 lp2 lp3 lp4 f1 f2 f3 f4]a
               )

      assert ChildOfMany.__properties__() == %{
               dp1: %Grax.Schema.DataProperty{
                 name: :dp1,
                 iri: ~I<http://example.com/dp1>,
                 schema: ChildOfMany,
                 from_rdf: {ParentSchema, :upcase}
               },
               dp2: %Grax.Schema.DataProperty{
                 name: :dp2,
                 iri: ~I<http://example.com/dp23>,
                 schema: ChildOfMany
               },
               dp3: %Grax.Schema.DataProperty{
                 name: :dp3,
                 iri: ~I<http://example.com/dp3>,
                 schema: ChildOfMany
               },
               dp4: %Grax.Schema.DataProperty{
                 name: :dp4,
                 iri: ~I<http://example.com/dp4>,
                 schema: ChildOfMany
               },
               lp1: %Grax.Schema.LinkProperty{
                 name: :lp1,
                 iri: ~I<http://example.com/lp1>,
                 schema: ChildOfMany,
                 on_rdf_type_mismatch: :ignore,
                 polymorphic: true,
                 type: {:resource, User}
               },
               lp2: %Grax.Schema.LinkProperty{
                 name: :lp2,
                 iri: ~I<http://example.com/lp2>,
                 schema: ChildOfMany,
                 on_rdf_type_mismatch: :ignore,
                 polymorphic: true,
                 type: {:resource, User}
               },
               lp3: %Grax.Schema.LinkProperty{
                 name: :lp3,
                 iri: ~I<http://example.com/lp3>,
                 schema: ChildOfMany,
                 on_rdf_type_mismatch: :ignore,
                 polymorphic: true,
                 type: {:resource, User}
               },
               lp4: %Grax.Schema.LinkProperty{
                 name: :lp4,
                 iri: ~I<http://example.com/lp4>,
                 schema: ChildOfMany,
                 on_rdf_type_mismatch: :ignore,
                 polymorphic: true,
                 type: {:resource, User}
               }
             }

      assert ChildOfMany.__custom_fields__() == %{
               f1: %Grax.Schema.CustomField{name: :f1},
               f2: %Grax.Schema.CustomField{name: :f2},
               f3: %Grax.Schema.CustomField{name: :f3},
               f4: %Grax.Schema.CustomField{name: :f4}
             }
    end

    test "inherit from nil" do
      defmodule InheritingFromNil do
        use Grax.Schema

        schema EX.Foo < nil do
          property foo: EX.foo()
        end
      end

      assert InheritingFromNil.__super__() == nil
    end

    test "multiple inheritance with conflicting property definitions" do
      assert_raise RuntimeError, fn ->
        defmodule ChildOfConflictingSchemas do
          use Grax.Schema

          schema inherit: [ParentSchema, AnotherParentSchema] do
          end
        end
      end

      assert_raise RuntimeError, fn ->
        defmodule ChildOfConflictingSchemas2 do
          use Grax.Schema

          schema inherit: [ParentSchema, AnotherParentSchema] do
            property dp2: EX.dp23()
          end
        end
      end
    end
  end

  describe "put/3" do
    test "with IRI" do
      assert PolymorphicLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.bar(),
               strict_one: EX.bar(),
               many: [EX.baz1(), EX.baz2()]
             ) ==
               {:ok,
                %PolymorphicLinks{
                  __id__: IRI.new(EX.Foo),
                  one: EX.bar(),
                  strict_one: EX.bar(),
                  many: [EX.baz1(), EX.baz2()]
                }}

      assert NonPolymorphicLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.bar(),
               strict_one: EX.bar(),
               many: [EX.baz1(), EX.baz2()]
             ) ==
               {:ok,
                %NonPolymorphicLinks{
                  __id__: IRI.new(EX.Foo),
                  one: EX.bar(),
                  strict_one: EX.bar(),
                  many: [EX.baz1(), EX.baz2()]
                }}
    end

    test "with bnode" do
      assert PolymorphicLinks.build!(EX.Foo)
             |> Grax.put(
               one: RDF.bnode("bar"),
               strict_one: RDF.bnode("bar"),
               many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
             ) ==
               {:ok,
                %PolymorphicLinks{
                  __id__: IRI.new(EX.Foo),
                  one: RDF.bnode("bar"),
                  strict_one: RDF.bnode("bar"),
                  many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
                }}

      assert NonPolymorphicLinks.build!(EX.Foo)
             |> Grax.put(
               one: RDF.bnode("bar"),
               strict_one: RDF.bnode("bar"),
               many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
             ) ==
               {:ok,
                %NonPolymorphicLinks{
                  __id__: IRI.new(EX.Foo),
                  one: RDF.bnode("bar"),
                  strict_one: RDF.bnode("bar"),
                  many: [RDF.bnode("baz1"), RDF.bnode("baz2")]
                }}
    end

    test "with vocabulary namespace term" do
      assert PolymorphicLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.Bar,
               strict_one: EX.Bar,
               many: [EX.baz(), EX.Baz1, EX.Baz2]
             ) ==
               {:ok,
                %PolymorphicLinks{
                  __id__: IRI.new(EX.Foo),
                  one: IRI.new(EX.Bar),
                  strict_one: IRI.new(EX.Bar),
                  many: [EX.baz(), IRI.new(EX.Baz1), IRI.new(EX.Baz2)]
                }}

      assert NonPolymorphicLinks.build!(EX.Foo)
             |> Grax.put(
               one: EX.Bar,
               strict_one: EX.Bar,
               many: [EX.baz(), EX.Baz1, EX.Baz2]
             ) ==
               {:ok,
                %NonPolymorphicLinks{
                  __id__: IRI.new(EX.Foo),
                  one: IRI.new(EX.Bar),
                  strict_one: IRI.new(EX.Bar),
                  many: [EX.baz(), IRI.new(EX.Baz1), IRI.new(EX.Baz2)]
                }}
    end

    test "with matching schema" do
      assert PolymorphicLinks.build!(EX.A)
             |> Grax.put(
               one: ParentSchema.build!(EX.B, dp2: 42),
               strict_one: AnotherParentSchema.build!(EX.B, dp2: 42),
               many: [ParentSchema.build!(EX.B, dp2: 42), ParentSchema.build!(EX.C, dp2: 43)]
             ) ==
               {:ok,
                %PolymorphicLinks{
                  __id__: IRI.new(EX.A),
                  one: ParentSchema.build!(EX.B, dp2: 42),
                  strict_one: AnotherParentSchema.build!(EX.B, dp2: 42),
                  many: [ParentSchema.build!(EX.B, dp2: 42), ParentSchema.build!(EX.C, dp2: 43)]
                }}

      assert NonPolymorphicLinks.build!(EX.A)
             |> Grax.put(
               one: ParentSchema.build!(EX.B, dp2: 42),
               strict_one: AnotherParentSchema.build!(EX.B, dp2: 42),
               many: [ParentSchema.build!(EX.B, dp2: 42), ParentSchema.build!(EX.C, dp2: 43)]
             ) ==
               {:ok,
                %NonPolymorphicLinks{
                  __id__: IRI.new(EX.A),
                  one: ParentSchema.build!(EX.B, dp2: 42),
                  strict_one: AnotherParentSchema.build!(EX.B, dp2: 42),
                  many: [ParentSchema.build!(EX.B, dp2: 42), ParentSchema.build!(EX.C, dp2: 43)]
                }}
    end

    test "polymorphic property with inherited schema" do
      assert PolymorphicLinks.build!(EX.A)
             |> Grax.put(
               one: ChildSchemaWithClass.build!(EX.B, dp4: 42),
               strict_one: AnotherParentSchema.build!(EX.B),
               many: [ChildSchemaWithClass.build!(EX.B, dp4: 42), ChildOfMany.build!(EX.C)]
             ) ==
               {:ok,
                %PolymorphicLinks{
                  __id__: IRI.new(EX.A),
                  one: ChildSchemaWithClass.build!(EX.B, dp4: 42),
                  strict_one: AnotherParentSchema.build!(EX.B),
                  many: [ChildSchemaWithClass.build!(EX.B, dp4: 42), ChildOfMany.build!(EX.C)]
                }}
    end

    test "non-polymorphic property with inherited schema" do
      assert NonPolymorphicLinks.build!(EX.A)
             |> Grax.put(:one, ChildSchemaWithClass.build!(EX.B)) ==
               {:error,
                TypeError.exception(
                  value: ChildSchemaWithClass.build!(EX.B),
                  type: ParentSchema
                )}

      assert NonPolymorphicLinks.build!(EX.A)
             |> Grax.put(:strict_one, ChildOfMany.build!(EX.B)) ==
               {:error,
                TypeError.exception(
                  value: ChildOfMany.build!(EX.B),
                  type: AnotherParentSchema
                )}

      assert NonPolymorphicLinks.build!(EX.A)
             |> Grax.put(:many, [ChildSchemaWithClass.build!(EX.B)]) ==
               {:error,
                TypeError.exception(
                  value: ChildSchemaWithClass.build!(EX.B),
                  type: ParentSchema
                )}
    end

    test "with non-matching schema" do
      assert PolymorphicLinks.build!(EX.A)
             |> Grax.put(:one, User.build!(EX.B)) ==
               {:error,
                TypeError.exception(
                  value: User.build!(EX.B),
                  type: ParentSchema
                )}

      assert PolymorphicLinks.build!(EX.A)
             |> Grax.put(:strict_one, ChildSchemaWithClass.build!(EX.B)) ==
               {:error,
                TypeError.exception(
                  value: ChildSchemaWithClass.build!(EX.B),
                  type: AnotherParentSchema
                )}

      assert PolymorphicLinks.build!(EX.A)
             |> Grax.put(many: [User.build!(EX.B), ChildOfMany.build!(EX.C)]) ==
               {
                 :error,
                 %Grax.ValidationError{
                   context: ~I<http://example.com/A>,
                   errors: [
                     many:
                       TypeError.exception(
                         value: User.build!(EX.B),
                         type: Example.ParentSchema
                       )
                   ]
                 }
               }

      assert NonPolymorphicLinks.build!(EX.A)
             |> Grax.put(:one, User.build!(EX.B)) ==
               {:error,
                TypeError.exception(
                  value: User.build!(EX.B),
                  type: ParentSchema
                )}

      assert NonPolymorphicLinks.build!(EX.A)
             |> Grax.put(:strict_one, ChildSchemaWithClass.build!(EX.B)) ==
               {:error,
                TypeError.exception(
                  value: ChildSchemaWithClass.build!(EX.B),
                  type: AnotherParentSchema
                )}

      assert NonPolymorphicLinks.build!(EX.A)
             |> Grax.put(many: [User.build!(EX.B), ChildOfMany.build!(EX.C)]) ==
               {
                 :error,
                 %Grax.ValidationError{
                   context: ~I<http://example.com/A>,
                   errors: [
                     many:
                       TypeError.exception(
                         value: ChildOfMany.build!(EX.C),
                         type: Example.ParentSchema
                       )
                   ]
                 }
               }
    end
  end

  describe "general preloading" do
    test "resource typed with schema class" do
      assert RDF.graph([
               EX.A |> EX.one(EX.B) |> EX.strictOne(EX.C),
               EX.B |> RDF.type(EX.Parent),
               EX.C |> RDF.type(EX.Parent2)
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one: ParentSchema.build!(EX.B),
                 strict_one: AnotherParentSchema.build!(EX.C)
               )

      assert RDF.graph([
               EX.A |> EX.one(EX.B) |> EX.strictOne(EX.C),
               EX.B |> RDF.type(EX.Parent),
               EX.C |> RDF.type(EX.Parent2)
             ])
             |> NonPolymorphicLinks.load(EX.A) ==
               NonPolymorphicLinks.build(EX.A,
                 one: ParentSchema.build!(EX.B),
                 strict_one: AnotherParentSchema.build!(EX.C)
               )
    end
  end

  describe "preloading polymorphic links" do
    test "resource typed with inherited schema class" do
      assert RDF.graph([
               EX.A |> EX.one(EX.B),
               EX.B |> RDF.type([EX.Child2]) |> EX.dp4(42)
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one: ChildSchemaWithClass.build!(EX.B, dp4: 42)
               )

      assert RDF.graph([
               EX.A |> EX.one(EX.B),
               EX.B |> RDF.type([EX.SubClass])
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one: ChildOfMany.build!(EX.B)
               )

      assert RDF.graph([
               EX.A |> EX.strictOne(EX.B),
               EX.B |> RDF.type([EX.SubClass])
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 strict_one: ChildOfMany.build!(EX.B)
               )

      assert RDF.graph([
               EX.A |> EX.many([EX.B, EX.C]),
               EX.B |> RDF.type([EX.Child2]),
               EX.C |> RDF.type([EX.SubClass])
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 many: [
                   ChildSchemaWithClass.build!(EX.B),
                   ChildOfMany.build!(EX.C)
                 ]
               )
    end

    test "resource typed with inherited schema class and parent schema classes too" do
      assert RDF.graph([
               EX.A |> EX.one(EX.B),
               EX.B |> RDF.type([EX.Parent, EX.Child2])
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one:
                   ChildSchemaWithClass.build!(EX.B,
                     __additional_statements__: %{RDF.type() => [EX.Parent, EX.Child2]}
                   )
               )

      [
        [EX.Parent, EX.SubClass],
        [EX.Parent2, EX.SubClass],
        [EX.Parent, EX.Parent2, EX.SubClass],
        [EX.Child2, EX.SubClass],
        [EX.Parent, EX.Parent2, EX.Child2, EX.SubClass]
      ]
      |> Enum.each(fn types ->
        assert RDF.graph([
                 EX.A |> EX.strictOne(EX.B),
                 EX.B |> RDF.type(types)
               ])
               |> PolymorphicLinks.load(EX.A) ==
                 PolymorphicLinks.build(EX.A,
                   strict_one:
                     ChildOfMany.build!(EX.B,
                       __additional_statements__: %{RDF.type() => types}
                     )
                 )
      end)
    end

    test "resource typed with non-matching class (non-strict)" do
      assert RDF.graph([
               EX.A |> EX.one(EX.B),
               EX.B |> RDF.type(EX.Unknown)
             ])
             |> PolymorphicLinks.load(EX.A) ==
               PolymorphicLinks.build(EX.A,
                 one:
                   ParentSchema.build!(EX.B,
                     __additional_statements__: %{RDF.type() => [EX.Parent, EX.Unknown]}
                   )
               )

      assert [
               example_description(:user),
               example_description(:post)
               |> Description.delete_predicates(RDF.type())
             ]
             |> Graph.new()
             |> Example.User.load(EX.User0) ==
               {:ok, Example.user(EX.User0, depth: 1)}
    end

    test "resource typed with non-matching class (strict)" do
      assert RDF.graph([
               EX.A |> EX.strictOne(EX.B),
               EX.B |> RDF.type(EX.Unknown)
             ])
             |> PolymorphicLinks.load(EX.A) ==
               {:error,
                InvalidResourceTypeError.exception(
                  type: :no_match,
                  resource_types: [RDF.iri(EX.Unknown)]
                )}
    end
  end

  describe "preloading non-strict non-polymorphic links" do
    test "resource typed with inherited schema class" do
      assert RDF.graph([
               EX.A
               |> EX.one(EX.B)
               |> EX.many(EX.C),
               EX.B |> RDF.type(EX.SubClass),
               EX.C |> RDF.type(EX.SubClass)
             ])
             |> NonPolymorphicLinks.load(EX.A) ==
               NonPolymorphicLinks.build(EX.A,
                 one:
                   ParentSchema.build!(EX.B,
                     __additional_statements__: %{RDF.type() => [EX.Parent, EX.SubClass]}
                   ),
                 many: [
                   ParentSchema.build!(EX.C,
                     __additional_statements__: %{RDF.type() => [EX.Parent, EX.SubClass]}
                   )
                 ]
               )
    end

    test "resource typed with both schema class and inherited schema class" do
      assert RDF.graph([
               EX.A |> EX.one(EX.B),
               EX.B |> RDF.type([EX.Parent, EX.Child2])
             ])
             |> NonPolymorphicLinks.load(EX.A) ==
               NonPolymorphicLinks.build(EX.A,
                 one:
                   ParentSchema.build!(EX.B,
                     __additional_statements__: %{RDF.type() => [EX.Parent, EX.Child2]}
                   )
               )
    end
  end

  describe "preloading strict non-polymorphic links" do
    test "resource typed with inherited schema class" do
      assert RDF.graph([
               EX.A |> EX.strictOne(EX.B),
               EX.B |> RDF.type(EX.SubClass)
             ])
             |> NonPolymorphicLinks.load(EX.A) ==
               NonPolymorphicLinks.build(EX.A,
                 strict_one:
                   AnotherParentSchema.build!(EX.B,
                     __additional_statements__: %{RDF.type() => [EX.Parent2, EX.SubClass]}
                   )
               )
    end

    test "resource typed with both schema class and inherited schema class" do
      assert RDF.graph([
               EX.A |> EX.strictOne(EX.B),
               EX.B |> RDF.type([EX.Parent2, EX.Child2])
             ])
             |> NonPolymorphicLinks.load(EX.A) ==
               NonPolymorphicLinks.build(EX.A,
                 strict_one:
                   AnotherParentSchema.build!(EX.B,
                     __additional_statements__: %{RDF.type() => [EX.Parent2, EX.Child2]}
                   )
               )
    end

    test "resource typed with non-matching class" do
      assert RDF.graph([
               EX.A |> EX.strictOne(EX.B),
               EX.B |> RDF.type(EX.Parent)
             ])
             |> NonPolymorphicLinks.load(EX.A) ==
               {:error,
                InvalidResourceTypeError.exception(
                  type: :no_match,
                  resource_types: [RDF.iri(EX.Parent)]
                )}
    end
  end

  test "paths/1" do
    assert Inheritance.paths(User) == []
    assert Inheritance.paths(ParentSchema) == []
    assert Inheritance.paths(ChildSchema) == [[ParentSchema]]
    assert Inheritance.paths(ChildSchemaWithClass) == [[ParentSchema]]

    assert Inheritance.paths(ChildOfMany) == [
             [ParentSchema],
             [AnotherParentSchema],
             [ChildSchemaWithClass, ParentSchema]
           ]
  end

  test "inherited_schema?/2" do
    assert Inheritance.inherited_schema?(ParentSchema, ParentSchema)
    assert Inheritance.inherited_schema?(ChildSchema, ParentSchema)
    assert Inheritance.inherited_schema?(ChildSchemaWithClass, ParentSchema)
    assert Inheritance.inherited_schema?(ChildOfMany, ParentSchema)
    assert Inheritance.inherited_schema?(ChildOfMany, AnotherParentSchema)
    assert Inheritance.inherited_schema?(ChildOfMany, ChildSchemaWithClass)

    refute Inheritance.inherited_schema?(User, ParentSchema)
    refute Inheritance.inherited_schema?(ChildSchema, User)
    refute Inheritance.inherited_schema?(ChildOfMany, User)
    refute Inheritance.inherited_schema?(AnotherParentSchema, ParentSchema)
  end
end
