from flask import Flask, jsonify, request
import random

app = Flask(__name__)

@app.route('/greet', methods=['GET'])
def greet():
    name = request.args.get('name', 'Stranger')
    random_num = random.randint(10000, 99999)
    return jsonify(message=f"Hello there! You'll be known here as {name}{random_num}. Welcome!")

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

