import asyncio
import httpx
import random
import time
import json
import sys
import os

# BASE = "http://localhost:5000"
BASE = os.getenv("MICRO_TARGET", "http://localhost:5000")

# All endpoints mapped to their call logic
ENDPOINTS = {
    "GET_/": lambda c: c.get(f"{BASE}/"),
    "GET_/echo": lambda c: c.get(f"{BASE}/echo", params={"text": "hello"}),
    "GET_/items": lambda c: c.get(f"{BASE}/items/{random.randint(1,9999)}"),
    "POST_/compute": lambda c: c.post(f"{BASE}/compute", json={"a": 5, "b": 6}),
    "GET_/compute/cpu": lambda c: c.get(f"{BASE}/compute/cpu"),
    "GET_/compute/mem": lambda c: c.get(f"{BASE}/compute/mem"),
    "GET_/io/disk": lambda c: c.get(f"{BASE}/io/disk"),
    "GET_/latency/low": lambda c: c.get(f"{BASE}/latency/low"),
    "GET_/latency/medium": lambda c: c.get(f"{BASE}/latency/medium"),
    "GET_/latency/high": lambda c: c.get(f"{BASE}/latency/high"),
    "GET_/race": lambda c: c.get(f"{BASE}/race"),
    "GET_/error": lambda c: c.get(f"{BASE}/error"),
}

# Ratio definitions
MIXES = {
    "balanced": {
        "GET_/": 10, "GET_/echo": 10, "GET_/items": 10,
        "POST_/compute": 10, "GET_/compute/cpu": 15,
        "GET_/compute/mem": 15, "GET_/io/disk": 10,
        "GET_/latency/low": 10, "GET_/latency/medium": 5,
        "GET_/error": 5,
    },
    "heavy_cpu": {
        "GET_/compute/cpu": 55,
        "GET_/compute/mem": 25,
        "GET_/io/disk": 10,
        "GET_/latency/high": 10,
    },
    "heavy_io": {
        "GET_/io/disk": 60,
        "POST_/compute": 20,
        "GET_/latency/high": 20,
    },
}

async def worker(endpoint_probs, stop_at, stats):
    async with httpx.AsyncClient(timeout=15) as client:
        while time.time() < stop_at:
            ep = random.choices(list(endpoint_probs.keys()), weights=endpoint_probs.values())[0]
            func = ENDPOINTS[ep]
            start = time.time()
            try:
                r = await func(client)
                latency = (time.time() - start) * 1000
                stats[ep]["count"] += 1
                stats[ep]["latencies"].append(latency)
                if r.status_code >= 400:
                    stats[ep]["errors"] += 1
            except Exception:
                stats[ep]["errors"] += 1

async def run_mix(mix, duration, concurrency):
    endpoint_probs = {k:v for k,v in MIXES[mix].items()}
    stats = {k: {"count": 0, "latencies": [], "errors": 0} for k in endpoint_probs}

    stop_at = time.time() + duration
    tasks = [worker(endpoint_probs, stop_at, stats) for _ in range(concurrency)]
    await asyncio.gather(*tasks)

    for ep, data in stats.items():
        if data["latencies"]:
            data["avg_ms"] = sum(data["latencies"]) / len(data["latencies"])
        else:
            data["avg_ms"] = 0

    print(json.dumps({"mix": mix, "results": stats}, indent=2))

if __name__ == "__main__":
    mix = sys.argv[1]
    duration = int(sys.argv[2])
    concurrency = int(sys.argv[3])
    asyncio.run(run_mix(mix, duration, concurrency))
