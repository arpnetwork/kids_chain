defmodule KidsChain.PipelineInstrumenter do
  use Prometheus.PlugPipelineInstrumenter

  def label_value(:request_path, conn) do
    if String.starts_with?(conn.request_path, "/users/") do
      "/users/UID"
    else
      conn.request_path
    end
  end
end
