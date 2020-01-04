use Mix.Config

path = Path.join(__DIR__, "service_account.json")

if File.exists?(path) do
  config :goth,
    json: File.read!(path)
else
  config :goth,
    disabled: true
end

config :avro_utils,
  project_id: "api-project-697138695705",
  dataset_id: "avro_utils"

config :tesla,
  adapter: {Tesla.Adapter.Hackney, []}
