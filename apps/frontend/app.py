from flask import Flask, render_template, request
import requests
import os

app = Flask(__name__)
backend_url = os.environ.get("BACKEND_URL", "http://backend:5000/greet")

@app.route("/", methods=["GET", "POST"])
def index():
    message = None
    if request.method == "POST":
        name = request.form.get("name")
        response = requests.get(backend_url, params={"name": name})
        message = response.json().get("message")
    return render_template("index.html", message=message)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

