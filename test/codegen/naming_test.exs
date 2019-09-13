defmodule KazanCodegenNamingTest do
  use ExUnit.Case

  alias Kazan.Codegen.Naming

  describe "model_name_to_module" do
    test "returns nil when unknown name in safe mode" do
      assert Naming.model_name_to_module("io.k8s.api.core.v1.nope") == nil
    end

    test "returns a module name when in unsafe mode" do
      mod_name =
        Naming.model_name_to_module(
          "io.k8s.api.core.v1.something",
          unsafe: true
        )

      assert mod_name == Kazan.Apis.Core.V1.Something
    end

    test "returns actual core module names" do
      mod_name = Naming.model_name_to_module("io.k8s.api.core.v1.Binding")
      assert mod_name == Kazan.Apis.Core.V1.Binding
    end
  end

  describe "k8s_name_to_module_name/1" do
    test "returns the module name given a k8s_name" do
      k8s_name = K8s.Io.Apimachinery.Pkg.Apis.Meta.V1.ObjectMeta
      expected = Kazan.Models.Apimachinery.Meta.V1.ObjectMeta

      assert Naming.k8s_name_to_module_name(k8s_name) == expected
    end
  end
end
