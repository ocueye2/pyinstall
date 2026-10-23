from flask import Flask
import sys
app = Flask("test")

@app.route("/")
def index():
    return f"arguments: {sys.argv}"


def main():
    app.run()


if __name__ == "__main__":
    main()
