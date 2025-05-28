import os
from dotenv import load_dotenv

from mysql.connector import Error

import mysql.connector

import json

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


def fetch_all_users():
    conn = get_db_connection()
    if not conn:
        return []

    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM Users")
        result = cursor.fetchall()
        return result
    finally:
        cursor.close()
        conn.close()


def get_chats(uid):
    conn = get_db_connection()
    if not conn:
        return None

    cursor = conn.cursor(dictionary=True)
    try:
        # Get chat ids from Users table (Chats column)
        cursor.execute("SELECT Chats FROM Users WHERE UserId = %s", (uid,))
        row = cursor.fetchone()
        print(f"Fetched row for user {uid}: {row}")

        if not row or not row.get("Chats"):  # type: ignore
            return []

        chat_ids = json.loads(row["Chats"])  # type: ignore
        print(f"Chat IDs for user {uid}: {chat_ids}")
        if not chat_ids:
            print(f"No chats found for user {uid}.")
            return []

        # Fetch chats from Chats table
        format_strings = ','.join(['%s'] * len(chat_ids))
        query = f"SELECT * FROM Chats WHERE Id IN ({format_strings})"
        cursor.execute(query, tuple(chat_ids))
        chats = cursor.fetchall()
        return chats
    finally:
        cursor.close()
        conn.close()


def add_user(uid, display_name, email, photo_url):
    conn = get_db_connection()
    if not conn:
        return False

    cursor = conn.cursor()
    try:
        # Check if user already exists
        cursor.execute("SELECT COUNT(*) FROM Users WHERE UserId = %s", (uid,))
        count = cursor.fetchone()[0]  # type: ignore
        if count > 0:  # type: ignore
            print(f"User {uid} already exists.")
            return False

        cursor.execute(
            "INSERT INTO Users (UserId, DisplayName, Email, PhotoUrl) VALUES (%s, %s, %s, %s)",
            (uid, display_name, email, photo_url)
        )
        conn.commit()
        print(f"User {uid} added successfully.")
        return True
    except Error as e:
        print(f"Error adding user: {e}")
        return False
    finally:
        cursor.close()
        conn.close()


# print(json.loads(fetch_all_users()[0]["Scores"]))
print(get_chats("W23Blk4eMzWHyNFrIbT8LrXfAdR2"))
