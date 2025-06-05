from db_connector import get_db_connection
from mysql.connector.abstracts import MySQLConnectionAbstract
from mysql.connector.pooling import PooledMySQLConnection


conn: (PooledMySQLConnection | MySQLConnectionAbstract |
       None) = get_db_connection()


def verify_conn():
    global conn

    if not conn:
        conn = get_db_connection()

    if conn and not conn.is_connected():
        print("[DEBUG] Reconnecting to the database...")
        conn = get_db_connection()


class DbUtils:
    global conn

    def __init__(self, query: str, params: tuple = ()):
        self.query = query
        self.params = params

    def execute(self):
        global conn
        verify_conn()

        if not conn:
            return None
        try:
            conn.rollback()
        except Exception:
            pass
        try:
            cursor = conn.cursor(dictionary=True)
            print("[DEBUG] Executing query:", self.query,
                  "with params:", self.params)
            cursor.execute(self.query, self.params)
            result = cursor.fetchall()
            cursor.close()
            return result
        except Exception as e:
            print(f"Query execution error: {e}")
            return None

    def execute_single(self):
        global conn
        verify_conn()

        if not conn:
            return None
        try:
            conn.rollback()
        except Exception:
            pass
        try:
            cursor = conn.cursor(dictionary=True)
            print("[DEBUG] Executing query:", self.query,
                  "with params:", self.params)
            cursor.execute(self.query, self.params)
            result = cursor.fetchone()
            cursor.close()
            return result
        except Exception as e:
            print(f"Query execution error: {e}")
            return None

    def execute_update(self):
        global conn
        verify_conn()

        if not conn:
            return False
        try:
            conn.rollback()
        except Exception:
            pass
        try:
            cursor = conn.cursor()
            print("[DEBUG] Executing update query:", self.query,
                  "with params:", self.params)
            cursor.execute(self.query, self.params)
            conn.commit()
            cursor.close()
            return True
        except Exception as e:
            print(f"Query execution error: {e}")
            return False
