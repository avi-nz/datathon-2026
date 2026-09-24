import json
import os
import requests
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("OPENROUTER_API_KEY")

if not API_KEY:
    raise ValueError("OPENROUTER_API_KEY is not set")

# Get the GP note from the user
with open("semi-urgent_referral.txt", "r", encoding="utf-8") as file:
    gp_note = file.read()

url = "https://openrouter.ai/api/alpha/decisions"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

data = {
    "model": "typesafe/jev-1.13",

    "state": gp_note,

    "questions": {
        "urgency": {
            "type": "choice",

            "instructions": """
            Based on the GP referral note, which treatment
            urgency category best describes this referral?
            """,

            "criteria": {
                "urgent": """
                The GP note contains a clear indication that the patient
                needs priority clinical assessment or treatment. Examples
                include sudden severe symptoms, rapidly worsening symptoms,
                or an explicit request for urgent assessment.
                """,

                "semi-urgent": """
                The GP note indicates that the patient needs clinical
                assessment within a shorter timeframe than a routine
                referral. The condition may be persistent, worsening,
                or affecting normal daily activities, but the note does
                not indicate an immediate or emergency need.
                """,

                "routine": """
                The GP note describes a stable or non-worsening condition
                where routine assessment or treatment is appropriate.
                There is no clear indication that the referral requires
                priority or time-sensitive assessment.
                """
            }
        }
    }
}

response = requests.post(
    url,
    headers=headers,
    json=data
)

print("\nStatus:", response.status_code)
print("Response:")
print(json.dumps(response.json(), indent=4))
