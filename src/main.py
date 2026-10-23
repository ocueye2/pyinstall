from flask import Flask
import sys
app = Flask("test")

@app.route("/")
def index():
    return f"arguments: {sys.argv}"

app.run()