import os
import requests
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("OPENROUTER_API_KEY")

if not API_KEY:
    raise ValueError("OPENROUTER_API_KEY is not set")

# Get the GP note from the user
with open("routine_referral.txt", "r", encoding="utf-8") as file:
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
                "urgent": "The GP note indicates that the patient requires priority or prompt clinical assessment.",

                "semi-urgent": "The GP note indicates that treatment or assessment is needed soon, but there is no clear indication of immediate urgency.",

                "routine": "The GP note indicates that treatment or assessment is required, but there are no documented indicators requiring priority treatment."
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
print(response.text)
