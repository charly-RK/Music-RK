from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return "Server is running!"

@app.route('/test')
def test():
    return jsonify({"message": "Test endpoint works!"})

if __name__ == '__main__':
    print("Test server starting...")
    app.run(host='0.0.0.0', port=5000, debug=False)
