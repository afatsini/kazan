defmodule Kazan.Swagger do
  @moduledoc false
  # Pre-processing utilities for Kube swagger data.

  # Takes a swagger dictionary and builds a map of
  # operation_name => operation
  def swagger_to_op_map(swagger_map) do
    swagger_parameters = swagger_map["parameters"]

    swagger_map["paths"]
    |> Enum.flat_map(fn {path, path_data} ->
      path_data_parameters = Map.get(path_data, "parameters", %{})
      method_maps = Map.delete(path_data, "parameters")

      Enum.map(method_maps, fn {method, operation} ->
        operation_parameters =
          parameters_with_ref(Map.get(operation, "parameters", %{}), swagger_parameters)

        path_parameters = parameters_with_ref(path_data_parameters, swagger_parameters)
        parameters = (operation_parameters ++ path_parameters) |> Enum.uniq()

        operation
        |> Map.put("path", path)
        |> Map.put("method", method)
        |> Map.put("parameters", parameters)
      end)
    end)
    |> Enum.map(fn operation ->
      {operation["operationId"], operation}
    end)
    |> Enum.into(%{})
  end

  # Enriches the parameters with the $ref parameters
  defp parameters_with_ref(parameters, swagger_parameters) do
    parameters
    |> Enum.flat_map(fn definition ->
      ref_params =
        definition
        |> Enum.filter(fn {k, _} -> k == "$ref" end)
        |> Enum.map(fn {_k, v} ->
          parameter_name = String.split(v, "/") |> List.last()
          swagger_parameters[parameter_name]
        end)

      standard_params = definition |> Enum.reject(fn {k, _} -> k == "$ref" end) |> Map.new()

      ref_params ++ [standard_params]
    end)
    |> Enum.reject(fn x -> map_size(x) == 0 end)
  end
end
