import azure.functions as func
import json
import os
from azure.data.tables import TableServiceClient
from azure.core.exceptions import ResourceNotFoundError

app = func.FunctionApp()
@app.route(route="visitor_count", auth_level=func.AuthLevel.ANONYMOUS)
def visitor_count(req: func.HttpRequest) -> func.HttpResponse:
    try:
        # Get connection string
        connection_string = os.environ["COSMOS_CONN_STRING"]

        # Create table client
        table_service_client = TableServiceClient.from_connection_string(connection_string)
        table_client = table_service_client.get_table_client("functions-cosmos-table")

        # Try to get existing count
        try:
            entity = table_client.get_entity(partition_key="visitors", row_key="count")
            current_count = entity.get("count", 0)
        except ResourceNotFoundError:
            # Create initial entity if it doesn't exist
            current_count = 0

        # Increment count
        new_count = current_count + 1

        # Update or create entity
        entity = {
            "PartitionKey": "visitors",
            "RowKey": "count",
            "count": new_count
        }

        table_client.upsert_entity(entity)

        return func.HttpResponse(
            json.dumps({"count": new_count}),
            status_code=200,
            headers={
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type"
            }
        )

    except Exception as e:
        return func.HttpResponse(
            f"Error: {str(e)}",
            status_code=500
        )