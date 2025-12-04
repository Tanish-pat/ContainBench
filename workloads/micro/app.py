# from flask import Flask, jsonify
# app = Flask(__name__)
# @app.route("/")
# def index():
#     return jsonify({"message": "Rootless container microservice running"})
# if __name__ == "__main__":
#     app.run(host="0.0.0.0", port=5000)
from flask import Flask, jsonify, request
import time
import random
import os

app = Flask(__name__)

# ----------------------------------------------------------------------
# CORE HEALTH & METADATA
# ----------------------------------------------------------------------
@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "micro-bench"})


@app.route("/info")
def info():
    return jsonify({
        "service": "micro-bench",
        "version": "1.0",
        "description": "Benchmark-oriented microservice",
        "endpoints": [
            "/",
            "/echo",
            "/items/<id>",
            "/compute",
            "/compute/cpu",
            "/compute/mem",
            "/io/disk",
            "/latency/<ms>",
            "/race",
            "/error"
        ]
    })


@app.route("/")
def index():
    return jsonify({"message": "Rootless container microservice running", "status": "healthy"})


# ----------------------------------------------------------------------
# BASIC TESTS (kept from earlier)
# ----------------------------------------------------------------------
@app.route("/echo")
def echo():
    text = request.args.get("text", "none")
    return jsonify({"echo": text})


@app.route("/items/<int:item_id>")
def get_item(item_id):
    return jsonify({
        "item_id": item_id,
        "details": f"Item metadata for {item_id}",
    })


@app.route("/compute", methods=["POST"])
def compute():
    data = request.get_json(silent=True) or {}
    a = data.get("a")
    b = data.get("b")

    if a is None or b is None:
        return jsonify({"error": "Missing required fields a and b"}), 400

    return jsonify({"result": a + b})


# ----------------------------------------------------------------------
# CPU WORKLOAD (wrk stress test compatible)
# ----------------------------------------------------------------------
@app.route("/compute/cpu")
def compute_cpu():
    n = int(request.args.get("n", 50000))
    s = 0
    for i in range(n):
        s += i * i
    return jsonify({"task": "cpu", "n": n, "result": s})


# ----------------------------------------------------------------------
# MEMORY WORKLOAD
# ----------------------------------------------------------------------
@app.route("/compute/mem")
def compute_mem():
    size_mb = int(request.args.get("mb", 10))
    block = b'x' * (size_mb * 1024 * 1024)
    return jsonify({"task": "memory", "allocated_mb": size_mb})


# ----------------------------------------------------------------------
# DISK I/O WORKLOAD
# ----------------------------------------------------------------------
@app.route("/io/disk")
def io_disk():
    size_kb = int(request.args.get("kb", 256))
    path = "/tmp/io_test.bin"

    with open(path, "wb") as f:
        f.write(os.urandom(size_kb * 1024))

    return jsonify({"task": "disk", "written_kb": size_kb})


# ----------------------------------------------------------------------
# LATENCY INJECTION
# ----------------------------------------------------------------------
@app.route("/latency/<int:ms>")
def latency(ms):
    time.sleep(ms / 1000)
    return jsonify({"latency_ms": ms, "status": "delayed"})


# ----------------------------------------------------------------------
# CONCURRENCY / RACE CONDITION TEST
# ----------------------------------------------------------------------
@app.route("/race")
def race():
    # Generates different answers under high concurrency if app code is faulty.
    t = time.time()
    time.sleep(0.0001)
    return jsonify({"timestamp": t})


# ----------------------------------------------------------------------
# FAULT INJECTION
# ----------------------------------------------------------------------
@app.route("/error")
def error():
    return jsonify({"error": "Simulated server failure"}), 500


# ----------------------------------------------------------------------
# MAIN ENTRYPOINT
# ----------------------------------------------------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
