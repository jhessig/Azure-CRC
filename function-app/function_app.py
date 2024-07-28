import azure.functions as func
import datetime
import json
import logging

app = func.FunctionApp()

@app.route(route="TestHttpTrigger", auth_level=func.AuthLevel.FUNCTION)
def TestHttpTrigger(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    name = req.params.get('name')
    if not name:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            name = req_body.get('name')

    if name:
        return func.HttpResponse(f"Hello, {name}. This HTTP triggered function uploaded and executed successfully.")
    else:
        return func.HttpResponse(
             "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.",
             status_code=200
        )

@app.route()
@app.cosmos_db_output(arg_name="documents",
                      database_name="DB_NAME",
                      collection_name="COLLECTION_NAME",
                      create_if_not_exists=True,
                      connection_string_setting="CONNECTION_SETTING")
def main(req: func.HttpRequest, documents: func.Out[func.Document]) -> func.HttpResponse:
    request_body = req.get_body()
    documents.set(func.Document.from_json(request_body))
    return 'OK'