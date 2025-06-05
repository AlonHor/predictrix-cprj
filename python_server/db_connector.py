import os
from dotenv import load_dotenv

from mysql.connector import Error

import mysql.connector

import firebase_admin
from firebase_admin import credentials

load_dotenv()


def get_db_connection():
    try:
        connection = mysql.connector.connect(
            host=os.environ.get('DB_HOST'),
            user=os.environ.get('DB_USER'),
            password=os.environ.get('DB_PASSWORD'),
            database=os.environ.get('DB_NAME'),
            port=int(os.environ.get('DB_PORT', 3306))
        )
        return connection
    except Error as e:
        print(f"Error connecting to MariaDB: {e}")
        return None


if not firebase_admin._apps:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
