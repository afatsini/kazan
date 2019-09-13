defmodule Kazan.Codegen.Naming do
  @moduledoc false
  # This module provides shared functions for converting things to model/api
  # names.

  alias Kazan.Config

  @doc """
  Parses a $ref for a definition into a models module name.
  """
  @spec definition_ref_to_model_module(String.t() | nil) :: nil | :atom
  def definition_ref_to_model_module(nil), do: nil

  # TODO: test
  def definition_ref_to_model_module("#/definitions/" <> model_def) do
    model_name_to_module(model_def)
  end

  @doc """
  Builds a module name atom from an OAI model name.
  """
  @spec model_name_to_module(String.t(), Keyword.t()) :: atom | nil
  def model_name_to_module(model_name, opts \\ []) do
    components = module_name_components(model_name)

    if Keyword.get(opts, :unsafe, false) do
      Module.concat(components)
    else
      try do
        Module.safe_concat(components)
      rescue
        ArgumentError ->
          nil
      end
    end
  end

  @doc """
  Builds a k8s name atom from an OAI model name.
  """
  @spec model_name(String.t(), Keyword.t()) :: atom | nil
  def model_name(model_name, opts \\ []) do
    [_definition , _k8s| components] = to_components(model_name)

    components = [K8s | [Io | components]]
    if Keyword.get(opts, :unsafe, false) do
      Module.concat(components)
    else
      try do
        Module.safe_concat(components)
      rescue
        ArgumentError ->
          nil
      end
    end
  end

  def k8s_name_to_module_name(k8s_name) do
    ["Elixir", "K8s", "Io" | namespace_pieces] = k8s_name
    |> Atom.to_string
    |> String.split(".")

   case namespace_pieces do
      # Deprecated
      ["Pkg", "Api" | rest] ->
        [Kazan.Apis] ++ rest

      # Deprecated
      ["Pkg", "Apis" | rest] ->
        [Kazan.Apis] ++ rest

      ["Api" | rest] ->
        [Kazan.Apis] ++ rest

      ["Apimachinery", "Pkg", "Apis" | rest] ->
        [Kazan.Models.Apimachinery] ++ rest

      ["Apimachinery", "Pkg" | rest] ->
        [Kazan.Models.Apimachinery] ++ rest

      ["KubeAggregator", "Pkg", "Apis" | rest] ->
        [Kazan.Models.KubeAggregator] ++ rest

      ["ApiextensionsApiserver", "Pkg", "Apis", "Apiextensions" | rest] ->
        [Kazan.Apis.Apiextensions] ++ rest

      other ->
        other_string = Enum.join(other, ".")
        Config.oai_name_mappings()
        |> Enum.find(fn {oai_prefix, _} ->
          String.starts_with?(other_string, oai_prefix)
        end)
        |> case do
          nil ->
            raise Kazan.UnknownName, name: other

          {oai_prefix, module_prefix} ->
            [module_prefix] ++
              to_components(String.replace_leading(other, oai_prefix, ""))
        end
    end
    |> Module.concat()
  end

  # The Kube OAI specs have some extremely long namespace prefixes on them.
  # These really long names make for a pretty ugly API in Elixir, so we chop off
  # some common prefixes.
  # We also need to categorise things into API specific models or models that
  # live in the models module.
  @spec module_name_components(String.t()) ::
          nonempty_improper_list(atom, String.t())
  defp module_name_components(name) do
    case name do
      # Deprecated
      "io.k8s.kubernetes.pkg.api." <> rest ->
        [Kazan.Apis] ++ to_components(rest)

      # Deprecated
      "io.k8s.kubernetes.pkg.apis." <> rest ->
        [Kazan.Apis] ++ to_components(rest)

      "io.k8s.api." <> rest ->
        [Kazan.Apis] ++ to_components(rest)

      "io.k8s.apimachinery.pkg.apis." <> rest ->
        [Kazan.Models.Apimachinery] ++ to_components(rest)

      "io.k8s.apimachinery.pkg." <> rest ->
        [Kazan.Models.Apimachinery] ++ to_components(rest)

      "io.k8s.kube-aggregator.pkg.apis." <> rest ->
        [Kazan.Models.KubeAggregator] ++ to_components(rest)

      "io.k8s.apiextensions-apiserver.pkg.apis.apiextensions." <> rest ->
        [Kazan.Apis.Apiextensions] ++ to_components(rest)

      other ->
        Config.oai_name_mappings()
        |> Enum.find(fn {oai_prefix, _} ->
          String.starts_with?(other, oai_prefix)
        end)
        |> case do
          nil ->
            raise Kazan.UnknownName, name: other

          {oai_prefix, module_prefix} ->
            [module_prefix] ++
              to_components(String.replace_leading(other, oai_prefix, ""))
        end
    end
  end

  # Uppercases the first character of str
  # This is different from capitalize, in that it leaves the rest of the string
  # alone.
  defp titlecase_once(str) do
    first_letter = String.first(str)
    String.replace_prefix(str, first_letter, String.upcase(first_letter))
  end

  defp to_components(str) do
    str |> String.split(".") |> Enum.map(&titlecase_once/1)
  end
end
