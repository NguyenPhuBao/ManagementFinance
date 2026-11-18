"""Load one converted TabFormer user (results/app_users.json) into a FlowMoney test account on the LOCAL backend
(PersonFinance database, http://127.0.0.1:3000/api) through the app's own sync API.

  python -u app_load.py register N     create account nckh_uN (POST /register, no OTP)
  (log in on the device once: the app creates its two wallets and its copies of the default categories)
  python -u app_load.py push N         pull the account's default wallet + categories, then push the user's income
                                       and spending transactions and a monthly total budget for November 2026
Only the test account is written; nothing is hard-deleted. Credentials: username nckh_uN, password below.
"""
import json
import pathlib
import sys
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone

HERE = pathlib.Path(__file__).resolve().parent
API = "http://127.0.0.1:3000/api"
PASSWORD = "Nckh@2026"
VN = timezone(timedelta(hours=7))
NS = uuid.UUID("6f1c2a52-3b0e-4f43-9d7e-1a2b3c4d5e6f")


def call(method, path, body=None, token=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=None if body is None else json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json",
                                          **({"Authorization": f"Bearer {token}"} if token else {})})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def user(n):
    return json.loads((HERE / "results" / "app_users.json").read_text(encoding="utf-8"))[n - 1]


def utc(local):
    return datetime.fromisoformat(local).replace(tzinfo=VN).astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def login(n):
    s, b = call("POST", "/auth/login", {"username": f"nckh_u{n}", "password": PASSWORD})
    assert s == 200, (s, b)
    d = b.get("data", b)
    return d.get("accessToken") or d["tokens"]["accessToken"], d


def main():
    cmd, n = sys.argv[1], int(sys.argv[2])
    u = user(n)
    if cmd == "register":
        s, b = call("POST", "/auth/register", {"username": f"nckh_u{n}", "password": PASSWORD,
                                          "fullname": f"NCKH TabFormer {u['uid']}", "email": f"nckh.u{n}.tf{u['uid']}@example.com"})
        print(s, json.dumps(b, ensure_ascii=False)[:300])
        return
    token, d = login(n)
    s, pulled = call("GET", "/sync/pull?since=1970-01-01T00:00:00.000Z", token=token)
    assert s == 200, (s, pulled)
    data = pulled["data"]["data"]
    wallets = [w for w in data["wallets"] if not w.get("delete_at")]
    print("wallets", [(w["name"], w["type"], w["is_default"]) for w in wallets])
    wallet = next(w for w in wallets if w["type"] == "Cash")    # day-to-day spending from the cash wallet
    wid, idacc = wallet["idwallet"], wallet["idaccount"]
    by_name = {}
    for c in data["categories"]:
        if c["is_default"] or c.get("delete_at") or c.get("create_by") != idacc:
            continue
        by_name.setdefault(c["name_category"], c["idcategory"])
    print("categories", sorted(by_name))
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    ops = []
    for kind, rows in (("thu", u["income"]), ("chi", u["transactions"])):
        for k, t in enumerate(rows):
            tid = str(uuid.uuid5(NS, f"{u['uid']}|{kind}|{k}|{t['date']}|{t['amount']}"))
            ops.append({"localId": tid, "entity": "transaction", "operation": "create", "payload": {
                "id": tid, "walletId": wid, "categoryId": by_name[t["category"]], "idwallet_transfer": None,
                "amount": t["amount"] if kind == "thu" else -t["amount"], "type": "Transaction", "note": "",
                "dateTransaction": utc(t["date"]), "is_deleted": False, "update_at": now, "idaccount": idacc,
                "idhousehold": None, "idgoal": None, "idbill": None, "idfund_pair": None}})
    budget = round(u["budget"] / 1000) * 1000
    ops.append({"localId": str(uuid.uuid5(NS, f"{u['uid']}|budget")), "entity": "budget", "operation": "create", "payload": {
        "id": str(uuid.uuid5(NS, f"{u['uid']}|budget")), "idcategory": None, "total_amount": budget, "spent": 0,
        "threshold_warning_amount": None, "threshold_warning_percent": None, "over_spending": "Over",
        "over_amount": None, "start": utc("2026-11-01T00:00:00"), "end": None, "recurrence": True,
        "time_recurrence": "Month", "nexttime_recurrence": None, "note": "", "is_deleted": False,
        "update_at": now, "idaccount": idacc, "idhousehold": None}})
    bad = 0
    for i in range(0, len(ops), 500):
        s, b = call("POST", "/sync/push", {"clientId": f"nckh-loader-{n}", "pushedAt": now, "operations": ops[i:i + 500]}, token)
        res = b.get("data", b).get("results", [])
        fail = [r for r in res if r.get("status") not in ("synced", "success", "ok", "applied", "created", "updated")]
        bad += len(fail)
        print("push", i, s, json.dumps(b, ensure_ascii=False)[:600] if s != 200 else b.get("data", b).get("summary"), fail[:2])
    print("ops", len(ops), "budget", budget, "failed", bad)


if __name__ == "__main__":
    main()
