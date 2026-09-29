import json
import requests
from lib.utils import make_greeting

def handler(event, context):
    name = None
    qsp = event.get("queryStringParameters")
    if isinstance(qsp, dict):
        name = qsp.get("name")
    if not name and event.get("body") is not None:
        try:
            body = event["body"]
            if isinstance(body, str):
                body = json.loads(body)
            if isinstance(body, dict):
                name = body.get("name")
        except Exception:
            pass
    name = name or "World"
    msg = make_greeting(name)
    extra = {}
    try:
        r = requests.get("https://api.agify.io", params={"name": name}, timeout=5)
        if r.ok:
            extra = r.json()
    except Exception:
        extra = {}
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"message": msg, "agify": extra})
    }