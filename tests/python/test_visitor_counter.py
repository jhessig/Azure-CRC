import unittest
from unittest.mock import Mock, patch, MagicMock
import json
import azure.functions as func
import sys
import os

# Add the parent directory to the path so we can import our function
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../function-app'))
from function_app import visitor_count  # Import your function

class TestVisitorCounter(unittest.TestCase):

    @patch('function_app.TableServiceClient')
    def test_visitor_counter_new_visitor(self, mock_table_service):
        """Test visitor counter when no existing count exists"""
        # Mock the table client
        mock_table_client = MagicMock()
        mock_table_service.from_connection_string.return_value.get_table_client.return_value = mock_table_client

        # Simulate no existing entity (first visitor)
        from azure.core.exceptions import ResourceNotFoundError
        mock_table_client.get_entity.side_effect = ResourceNotFoundError("Entity not found")

        # Create mock request
        req = func.HttpRequest(
            method='POST',
            body=b'',
            url='https://test.com/api/visitor-count',
            headers={}
        )

        # Mock environment variable
        with patch.dict(os.environ, {'CosmosDBConnectionString': 'test_connection_string'}):
            response = main(req)

        # Assertions
        self.assertEqual(response.status_code, 200)
        response_data = json.loads(response.get_body())
        self.assertEqual(response_data['count'], 1)

        # Verify upsert was called with correct data
        mock_table_client.upsert_entity.assert_called_once()

    @patch('function_app.TableServiceClient')
    def test_visitor_counter_existing_count(self, mock_table_service):
        """Test visitor counter when existing count exists"""
        # Mock the table client
        mock_table_client = MagicMock()
        mock_table_service.from_connection_string.return_value.get_table_client.return_value = mock_table_client

        # Simulate existing entity with count of 5
        mock_entity = {'count': 5, 'PartitionKey': 'visitors', 'RowKey': 'count'}
        mock_table_client.get_entity.return_value = mock_entity

        # Create mock request
        req = func.HttpRequest(
            method='POST',
            body=b'',
            url='https://test.com/api/visitor-count',
            headers={}
        )

        # Mock environment variable
        with patch.dict(os.environ, {'CosmosDBConnectionString': 'test_connection_string'}):
            response = main(req)

        # Assertions
        self.assertEqual(response.status_code, 200)
        response_data = json.loads(response.get_body())
        self.assertEqual(response_data['count'], 6)

    @patch('function_app.TableServiceClient')
    def test_visitor_counter_database_error(self, mock_table_service):
        """Test visitor counter handles database errors gracefully"""
        # Mock the table client to raise an exception
        mock_table_service.from_connection_string.side_effect = Exception("Database connection failed")

        # Create mock request
        req = func.HttpRequest(
            method='POST',
            body=b'',
            url='https://test.com/api/visitor-count',
            headers={}
        )

        # Mock environment variable
        with patch.dict(os.environ, {'CosmosDBConnectionString': 'test_connection_string'}):
            response = main(req)

        # Assertions
        self.assertEqual(response.status_code, 500)
        self.assertIn("Error", response.get_body().decode())

    def test_cors_headers_present(self):
        """Test that CORS headers are present in response"""
        with patch('function_app.TableServiceClient'), \
             patch.dict(os.environ, {'CosmosDBConnectionString': 'test_connection_string'}):

            req = func.HttpRequest(
                method='POST',
                body=b'',
                url='https://test.com/api/visitor-count',
                headers={}
            )

            response = main(req)

            # Check CORS headers
            headers = dict(response.headers)
            self.assertIn('Access-Control-Allow-Origin', headers)
            self.assertEqual(headers['Content-Type'], 'application/json')

if __name__ == '__main__':
    unittest.main()