from fastapi import FastAPI, Form
from fastapi.responses import HTMLResponse
import requests
import uvicorn
from datetime import datetime

app = FastAPI(title="Healthcare Referral Portals")

PROXY_PIPELINE_URL = "http://localhost:8000/api/v1/referrals/ingest"

# --- GP PORTAL 1: Modern Web Application ---
HTML_INTERFACE_1 = """
<!DOCTYPE html>
<html>
<head>
    <title>Healthcare Referral Gateway</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; max-width: 550px; margin: 30px auto; padding: 25px; border: 1px solid #cbd5e1; border-radius: 8px; background-color: #f8fafc; }
        h2 { color: #0f172a; margin-top: 0; }
        .sub { color: #64748b; font-size: 14px; margin-bottom: 20px; }
        .field { margin-bottom: 12px; }
        label { display: block; font-weight: 600; color: #334155; margin-bottom: 4px; font-size: 14px; }
        input, select, textarea { width: 100%; padding: 8px; border: 1px solid #94a3b8; border-radius: 4px; box-sizing: border-box; font-size: 14px; }
        textarea { height: 80px; }
        button { background: #2563eb; color: white; padding: 10px; border: none; border-radius: 4px; width: 100%; font-size: 15px; font-weight: bold; cursor: pointer; margin-top: 10px; }
        button:hover { background: #1d4ed8; }
    </style>
</head>
<body>
    <h2>Healthcare Referral Gateway</h2>
    <div class="sub">Patient Referral Submission Form</div>
    <form action="/interface1/submit" method="post">
        <div class="field"><label>NHI Number</label><input type="text" name="nhi_number" placeholder="e.g. ABC1234" required></div>
        <div class="field"><label>Age</label><input type="number" name="age" placeholder="e.g. 45" required></div>
        <div class="field"><label>Gender</label><input type="text" name="gender" placeholder="e.g. Female / Male / Other"></div>
        <div class="field"><label>Existing Medical Conditions</label><input type="text" name="existing_conditions" placeholder="e.g. diabetes, hypertension"></div>
        <div class="field"><label>Patient Risk History</label><input type="text" name="risk_history" placeholder="e.g. previous urgent admission"></div>
        <div class="field"><label>GP Clinical Summary & Notes</label><textarea name="gp_notes" placeholder="Enter clinical notes and symptoms..."></textarea></div>
        <button type="submit">Submit Referral</button>
    </form>
</body>
</html>
"""

# --- GP PORTAL 2: 1998 Windows 95 Dinosaur Edition ---
HTML_INTERFACE_2 = """
<!DOCTYPE html>
<html>
<head>
    <title>CLINIC-SYS v2.14 (1998 build) - Outpatient Referral Module</title>
</head>
<body bgcolor="#C0C0C0" text="#000000" link="#0000FF" vlink="#800080">

<center>
<table border="3" cellpadding="8" cellspacing="0" bgcolor="#000080" width="600">
    <tr>
        <td align="center">
            <font color="#FFFFFF" face="Times New Roman" size="5">
                <b>*** CLINIC-SYS v2.14 ***</b><br>
                <font size="3">Primary Care Referral Form (DO NOT REFRESH PAGE)</font>
            </font>
        </td>
    </tr>
</table>

<br>

<form action="/interface2/submit" method="post">
<table border="2" cellpadding="4" cellspacing="2" bgcolor="#D4D0C8" width="600">
    <tr>
        <td width="30%" bgcolor="#808080"><font color="#FFFFFF" face="Times New Roman"><b>Patient NHI:</b></font></td>
        <td><input type="text" name="nhi_number" size="25" style="font-family: 'Courier New';" required></td>
    </tr>
    <tr>
        <td bgcolor="#808080"><font color="#FFFFFF" face="Times New Roman"><b>Age:</b></font></td>
        <td><input type="text" name="age" size="10" style="font-family: 'Courier New';" required></td>
    </tr>
    <tr>
        <td bgcolor="#808080"><font color="#FFFFFF" face="Times New Roman"><b>Gender:</b></font></td>
        <td><input type="text" name="gender" size="15" style="font-family: 'Courier New';"></td>
    </tr>
    <tr>
        <td bgcolor="#808080"><font color="#FFFFFF" face="Times New Roman"><b>Known Conditions:</b></font></td>
        <td><input type="text" name="conditions" size="40" style="font-family: 'Courier New';"></td>
    </tr>
    <tr>
        <td bgcolor="#808080"><font color="#FFFFFF" face="Times New Roman"><b>Risk & History:</b></font></td>
        <td><input type="text" name="riskNotes" size="40" style="font-family: 'Courier New';"></td>
    </tr>
    <tr>
        <td bgcolor="#808080" valign="top"><font color="#FFFFFF" face="Times New Roman"><b>Clinical Notes:</b></font></td>
        <td><textarea name="clinicalNotes" rows="5" cols="40" style="font-family: 'Courier New';"></textarea></td>
    </tr>
    <tr bgcolor="#C0C0C0">
        <td colspan="2" align="center">
            <br>
            <input type="submit" value=" SUBMIT DATA TO HOST SYSTEM " style="font-family: 'Times New Roman'; font-weight: bold; height: 35px; background-color: #C0C0C0; border: 3px double #000000;">
            <input type="reset" value=" CLEAR FORM " style="font-family: 'Times New Roman'; height: 35px; background-color: #C0C0C0; border: 3px double #000000;">
            <br><br>
        </td>
    </tr>
</table>
</form>

<font size="2" face="Times New Roman">
    <i>Connected to Terminal Server #4 | Protocol: HTTP/1.0 | Best viewed in Netscape Navigator 4.0</i>
</font>
</center>

</body>
</html>
"""

@app.get("/interface1", response_class=HTMLResponse)
def page_interface_1():
    return HTML_INTERFACE_1

@app.get("/interface2", response_class=HTMLResponse)
def page_interface_2():
    return HTML_INTERFACE_2

@app.post("/interface1/submit")
def submit_interface_1(
    nhi_number: str = Form(...), age: int = Form(...), gender: str = Form(""),
    existing_conditions: str = Form(""), risk_history: str = Form(""), gp_notes: str = Form("")
):
    payload = {
        "nhi_number": nhi_number,
        "age": age,
        "gender": gender,
        "existing_conditions": existing_conditions,
        "risk_history": risk_history,
        "gp_notes": gp_notes,
        "facility_id": "FAC-001",
        "submitting_gp_id": "GP-00123",
        "submitted_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    }
    try:
        res = requests.post(PROXY_PIPELINE_URL, json=payload, timeout=5)
        return {"message": "Referral successfully submitted!", "sent_json": payload}
    except Exception as e:
        return {"error": f"Failed to connect to pipeline server: {e}"}

@app.post("/interface2/submit")
def submit_interface_2(
    nhi_number: str = Form(...), age: int = Form(...), gender: str = Form(""),
    conditions: str = Form(""), riskNotes: str = Form(""), clinicalNotes: str = Form("")
):
    # Still sends the nested Interface 2 JSON under the hood!
    payload = {
        "patient": {
            "nhi_number": nhi_number,
            "demographics": { "age": age, "gender": gender },
            "clinicalHistory": { "conditions": conditions, "riskNotes": riskNotes }
        },
        "referral": {
            "clinicalNotes": clinicalNotes,
            "facility": "FAC-001",
            "referringGp": "GP-00123",
            "timestamp": datetime.now().strftime("%d-%m-%Y %H:%M")
        }
    }
    try:
        res = requests.post(PROXY_PIPELINE_URL, json=payload, timeout=5)
        return {"message": "Referral successfully submitted via legacy portal!", "sent_json": payload}
    except Exception as e:
        return {"error": f"Failed to connect to pipeline server: {e}"}

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=5050)