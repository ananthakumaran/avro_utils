defmodule AvroUtils.IntegrationTest do
  use ExUnit.Case
  require Logger
  alias GoogleApi.BigQuery.V2.Api.Jobs
  alias GoogleApi.BigQuery.V2.Connection

  alias GoogleApi.BigQuery.V2.Model.{
    TableReference,
    Job,
    JobConfiguration,
    JobConfigurationLoad,
    JobReference
  }

  @moduletag :integration

  test "load" do
    pairs =
      File.read!(Path.join(__DIR__, "../../fixture/schema.json"))
      |> Jason.decode!()

    Temp.track!()

    for %{"bq" => bq, "transforms" => transforms} <- pairs do
      data = Enum.map(transforms, fn %{"to" => to} -> [Jason.encode!(to), "\n"] end)
      upload(bq, "events", data)
    end
  end

  def upload(schema, table, data) do
    file_path = Temp.path!()
    File.write!(file_path, data)

    {:ok, job} =
      Jobs.bigquery_jobs_insert_simple(
        connection(),
        default_project_id(),
        "multipart",
        %Job{
          configuration: %JobConfiguration{
            jobType: "LOAD",
            load: %JobConfigurationLoad{
              destinationTable: %TableReference{
                projectId: default_project_id(),
                datasetId: default_dataset_id(),
                tableId: table
              },
              schema: schema,
              writeDisposition: "WRITE_TRUNCATE",
              sourceFormat: "NEWLINE_DELIMITED_JSON"
            }
          }
        },
        file_path
      )

    File.rm!(file_path)
    wait_till_done(job)
  end

  def get_job(job_id) do
    Jobs.bigquery_jobs_get(connection(), default_project_id(), job_id)
  end

  def wait_till_done(%Job{status: %{errorResult: nil, state: "DONE"} = status} = job) do
    Logger.info("BQ job completed, status #{inspect(status)}")
    job
  end

  def wait_till_done(%Job{status: %{state: "DONE"} = status} = job) do
    raise "BQ job failed, status: #{inspect(status)}, job: #{inspect(job)}"
  end

  def wait_till_done(%Job{jobReference: %JobReference{jobId: job_id}}) do
    Logger.info("Waiting for BQ job to complete")
    Process.sleep(5000)
    {:ok, job} = get_job(job_id)
    wait_till_done(job)
  end

  defp default_project_id() do
    Application.get_env(:avro_utils, :project_id)
  end

  defp default_dataset_id() do
    Application.get_env(:avro_utils, :dataset_id)
  end

  defp connection do
    {:ok, token} = Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform")
    Connection.new(token.token)
  end
end
