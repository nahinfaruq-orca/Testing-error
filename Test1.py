import os
import sqlite3
import hashlib
import pickle
from flask import Flask, request

app = Flask(__name__)

# Hardcoded secret key (bad practice)
SECRET_KEY = "super_secret_key_123"

@app.route("/login", methods=["POST"])
def login():
    username = request.form['username']
    password = request.form['password']

    # Insecure hash (fast and predictable)
    hashed_password = hashlib.md5(password.encode()).hexdigest()

    conn = sqlite3.connect('users.db')
    cursor = conn.cursor()

    # SQL Injection vulnerability
    query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{hashed_password}'"
    cursor.execute(query)
    result = cursor.fetchone()

    if result:
        return "Login successful"
    else:
        return "Invalid credentials"

@app.route("/run", methods=["POST"])
def run_command():
    cmd = request.form['cmd']

    # Command injection vulnerability
    os.system(cmd)
    return "Command executed"

@app.route("/load", methods=["POST"])
def load_data():
    payload = request.form['data']

    # Insecure deserialization vulnerability
    obj = pickle.loads(payload.encode())
    return f"Loaded: {obj}"

@app.route("/calculate", methods=["POST"])
def calculate():
    expr = request.form['expression']

    # Eval injection vulnerability
    result = eval(expr)
    return f"Result: {result}"

if __name__ == "__main__":
    app.run(debug=True)
