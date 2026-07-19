from dotenv import load_dotenv
load_dotenv()

import os
import json
import io
import base64
from datetime import datetime

import requests
from twilio.rest import Client
import smtplib
from email.mime.text import MIMEText

import cloudinary
import cloudinary.uploader

from fastapi import FastAPI, BackgroundTasks, HTTPException, UploadFile, File
from sqlalchemy import create_engine, Column, Integer, String, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import google.generativeai as genai

# ---- Database setup ----
DATABASE_URL = os.environ.get("DATABASE_URL")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()

# ---- Gemini setup ----
genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))
model = genai.GenerativeModel("gemini-3.5-flash")

# ---- Cloudinary setup ----
cloudinary.config(
    cloud_name=os.environ.get("CLOUDINARY_CLOUD_NAME"),
    api_key=os.environ.get("CLOUDINARY_API_KEY"),
    api_secret=os.environ.get("CLOUDINARY_API_SECRET")
)

# ---- Alert setup (Twilio + Email) ----
TWILIO_SID = os.environ.get("TWILIO_ACCOUNT_SID")
TWILIO_AUTH_TOKEN = os.environ.get("TWILIO_AUTH_TOKEN")
TWILIO_PHONE = os.environ.get("TWILIO_PHONE_NUMBER")
FAMILY_PHONE = os.environ.get("FAMILY_PHONE_NUMBER")

ALERT_EMAIL_ADDRESS = os.environ.get("ALERT_EMAIL_ADDRESS")
ALERT_EMAIL_PASSWORD = os.environ.get("ALERT_EMAIL_PASSWORD")
FAMILY_EMAIL = os.environ.get("FAMILY_EMAIL")

# ---- IPQualityScore setup ----
IPQS_API_KEY = os.environ.get("IPQS_API_KEY")

# ---- OpenAI setup ----
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")


def send_sms_alert(risk_level: str, explanation: str, phone_number: str = None):
    """Send SMS alert to family about scam detection"""
    try:
        client = Client(TWILIO_SID, TWILIO_AUTH_TOKEN)
        message_body = f"🚨 SCAM ALERT ({risk_level} risk): {explanation}"
        if phone_number:
            message_body += f"\n\nCaller: {phone_number}"
        
        client.messages.create(
            body=message_body,
            from_=TWILIO_PHONE,
            to=FAMILY_PHONE
        )
        print("SMS alert sent successfully")
    except Exception as e:
        print(f"SMS alert failed: {e}")


def send_email_alert(risk_level: str, explanation: str, transcript: str, phone_number: str = None):
    """Send email alert to family about scam detection"""
    try:
        warning_msg = f"""URGENT: High-risk scam call detected!

Risk Level: {risk_level}
Caller: {phone_number or 'Unknown'}

Explanation: {explanation}

Call transcript:
{transcript}

Please check on your family member immediately."""
        
        msg = MIMEText(warning_msg)
        msg["Subject"] = f"🚨 SCAM ALERT - {risk_level} Risk Detected"
        msg["From"] = ALERT_EMAIL_ADDRESS
        msg["To"] = FAMILY_EMAIL

        with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=10) as server:
            server.login(ALERT_EMAIL_ADDRESS, ALERT_EMAIL_PASSWORD)
            server.send_message(msg)
        print("Email alert sent successfully")
    except Exception as e:
        print(f"Email alert failed: {e}")


# ---- Database models ----
class Problem(Base):
    __tablename__ = "problems"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    difficulty = Column(String, nullable=False)
    date_solved = Column(DateTime, default=datetime.utcnow)
    notes = Column(String, nullable=True)


class CallAnalysis(Base):
    __tablename__ = "call_analyses"
    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String, nullable=True)
    transcript = Column(String, nullable=False)
    risk_level = Column(String, nullable=False)
    explanation = Column(String, nullable=True)
    flags = Column(String, nullable=True)
    flagged_phrases = Column(String, nullable=True)
    date_analyzed = Column(DateTime, default=datetime.utcnow)
    audio_url = Column(String, nullable=True)
    is_real_time = Column(Integer, default=0)


Base.metadata.create_all(bind=engine)


# ---- Pydantic models ----
class ProblemCreate(BaseModel):
    name: str
    difficulty: str
    notes: str | None = None


class TranscriptInput(BaseModel):
    transcript: str
    phone_number: str | None = None


class AudioChunkInput(BaseModel):
    """For real-time transcription of audio chunks"""
    audio_base64: str
    phone_number: str | None = None
    chunk_index: int = 0


# ---- App setup ----
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def read_root():
    return {"message": "hello from the cloud"}


# ---- Call analysis endpoints ----
@app.post("/analyze-call")
def analyze_call(data: TranscriptInput, background_tasks: BackgroundTasks):
    if not data.transcript or not data.transcript.strip():
        raise HTTPException(status_code=400, detail="Transcript cannot be empty")

    prompt = f"""You are a scam-detection assistant analyzing a phone call transcript for manipulation patterns targeting elderly individuals.

Analyze this transcript and respond ONLY with valid JSON in this exact format, no extra text, no markdown code blocks:
{{
  "risk_level": "Low or Medium or High",
  "flags": ["urgency_pressure", "authority_impersonation", "payment_request", "emotional_manipulation", "isolation_tactic"],
  "flagged_phrases": ["exact phrases from the transcript that triggered concern"],
  "explanation": "one plain-language sentence explaining the risk to an elderly user"
}}

Transcript: "{data.transcript}"
"""

    result = None
    last_error = None

    for attempt in range(2):
        try:
            response = model.generate_content(prompt)
            result_text = response.text.strip()

            if result_text.startswith("```"):
                result_text = result_text.strip("`").replace("json", "", 1).strip()

            parsed = json.loads(result_text)

            required_fields = ["risk_level", "flags", "flagged_phrases", "explanation"]
            if not all(field in parsed for field in required_fields):
                raise ValueError(f"Missing fields: {parsed}")

            if parsed["risk_level"] not in ["Low", "Medium", "High"]:
                raise ValueError(f"Invalid risk_level: {parsed['risk_level']}")

            result = parsed
            break

        except (json.JSONDecodeError, ValueError, KeyError) as e:
            last_error = e
            print(f"Attempt {attempt + 1} failed: {e}")
            continue
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"AI service error: {e}")

    if result is None:
        raise HTTPException(status_code=502, detail=f"Analysis failed: {last_error}")

    try:
        db = SessionLocal()
        new_analysis = CallAnalysis(
            phone_number=data.phone_number,
            transcript=data.transcript,
            risk_level=result["risk_level"],
            explanation=result["explanation"],
            flags=json.dumps(result["flags"]),
            flagged_phrases=json.dumps(result["flagged_phrases"])
        )
        db.add(new_analysis)
        db.commit()
        db.refresh(new_analysis)
        analysis_id = new_analysis.id
        db.close()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {e}")

    if result["risk_level"] in ["Medium", "High"]:
        background_tasks.add_task(send_sms_alert, result["risk_level"], result["explanation"], data.phone_number)
        background_tasks.add_task(send_email_alert, result["risk_level"], result["explanation"], data.transcript, data.phone_number)

    return {
        "id": analysis_id,
        "risk_level": result["risk_level"],
        "flags": result["flags"],
        "flagged_phrases": result["flagged_phrases"],
        "explanation": result["explanation"]
    }


@app.post("/transcribe-chunk")
async def transcribe_chunk(data: AudioChunkInput):
    """Transcribe audio chunk using OpenAI Whisper"""
    if not OPENAI_API_KEY:
        raise HTTPException(status_code=500, detail="OpenAI API key not configured")
    
    if not data.audio_base64:
        raise HTTPException(status_code=400, detail="Audio data is required")
    
    try:
        audio_bytes = base64.b64decode(data.audio_base64)
        
        files = {
            'file': ('audio.wav', io.BytesIO(audio_bytes), 'audio/wav'),
        }
        headers = {
            'Authorization': f'Bearer {OPENAI_API_KEY}'
        }
        
        response = requests.post(
            'https://api.openai.com/v1/audio/transcriptions',
            headers=headers,
            files=files,
            data={'model': 'whisper-1'},
            timeout=30
        )
        
        if response.status_code != 200:
            raise HTTPException(status_code=502, detail=f"Whisper API error: {response.text}")
        
        result = response.json()
        transcript = result.get('text', '').strip()
        
        return {
            "transcript": transcript,
            "chunk_index": data.chunk_index,
            "phone_number": data.phone_number
        }
        
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Transcription failed: {e}")


@app.post("/analyze-chunk")
async def analyze_chunk(data: TranscriptInput, background_tasks: BackgroundTasks):
    """Analyze transcript chunk in real-time"""
    return analyze_call(data, background_tasks)


@app.get("/check-number")
def check_number(phone: str):
    if not phone or not phone.strip():
        raise HTTPException(status_code=400, detail="Phone number is required")

    if not IPQS_API_KEY:
        raise HTTPException(status_code=500, detail="IPQualityScore API key is not configured")

    url = f"https://www.ipqualityscore.com/api/json/phone/{IPQS_API_KEY}/{phone.strip()}"

    try:
        response = requests.get(url, timeout=10)
        data = response.json()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"IPQualityScore request failed: {e}")

    if not data.get("success", False):
        raise HTTPException(status_code=502, detail=f"IPQualityScore error: {data.get('message')}")

    fraud_score = data.get("fraud_score", 0)
    if fraud_score >= 70 or data.get("recent_abuse", False):
        risk_level = "High"
    elif data.get("risky", False) or data.get("spammer", False) or fraud_score >= 40:
        risk_level = "Medium"
    else:
        risk_level = "Low"

    return {
        "phone": data.get("formatted", phone),
        "risk_level": risk_level,
        "fraud_score": fraud_score
    }


@app.post("/analyze-call-audio")
async def analyze_call_audio(audio: UploadFile = File(...), background_tasks: BackgroundTasks = None):
    if not audio.content_type or not audio.content_type.startswith("audio/"):
        raise HTTPException(status_code=400, detail="Uploaded file must be an audio file")

    audio_bytes = await audio.read()
    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Audio file is empty")

    # Upload to Cloudinary first, so the recording is kept even if the AI analysis step fails
    try:
        upload_result = cloudinary.uploader.upload(
            audio_bytes,
            resource_type="video",  # Cloudinary uses the 'video' resource type for audio files too
            folder="scam_safety_calls"
        )
        audio_url = upload_result.get("secure_url")
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Audio upload failed: {e}")

    prompt = """You are a scam-detection assistant. Listen to this audio recording of a phone call and:
1. Transcribe what is said.
2. Analyze it for manipulation patterns targeting elderly individuals.

Respond ONLY with valid JSON in this exact format, no extra text, no markdown code blocks:
{
  "transcript": "full transcription of the audio",
  "risk_level": "Low or Medium or High",
  "flags": ["list which apply: urgency_pressure, authority_impersonation, payment_request, emotional_manipulation, isolation_tactic"],
  "flagged_phrases": ["exact phrases that triggered concern"],
  "explanation": "one plain-language sentence explaining the risk to an elderly user"
}
"""

    result = None
    last_error = None

    for attempt in range(2):
        try:
            response = model.generate_content([
                prompt,
                {"mime_type": audio.content_type, "data": audio_bytes}
            ])
            result_text = response.text.strip()

            if result_text.startswith("```"):
                result_text = result_text.strip("`")
                result_text = result_text.replace("json", "", 1).strip()

            parsed = json.loads(result_text)

            required_fields = ["transcript", "risk_level", "flags", "flagged_phrases", "explanation"]
            if not all(field in parsed for field in required_fields):
                raise ValueError(f"Gemini response missing required fields: {parsed}")

            if parsed["risk_level"] not in ["Low", "Medium", "High"]:
                raise ValueError(f"Invalid risk_level value: {parsed['risk_level']}")

            result = parsed
            break

        except (json.JSONDecodeError, ValueError, KeyError) as e:
            last_error = e
            print(f"Attempt {attempt + 1} failed to parse Gemini response: {e}")
            continue
        except Exception as e:
            raise HTTPException(status_code=502, detail=f"AI analysis service unavailable: {e}")

    if result is None:
        raise HTTPException(
            status_code=502,
            detail=f"Could not get a valid analysis after retrying. Last error: {last_error}"
        )

    try:
        db = SessionLocal()
        new_analysis = CallAnalysis(
            transcript=result["transcript"],
            risk_level=result["risk_level"],
            explanation=result["explanation"],
            audio_url=audio_url
        )
        db.add(new_analysis)
        db.commit()
        db.refresh(new_analysis)
        analysis_id = new_analysis.id
        db.close()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {e}")

    if result["risk_level"] in ["Medium", "High"]:
        background_tasks.add_task(send_sms_alert, result["risk_level"], result["explanation"])
        background_tasks.add_task(send_email_alert, result["risk_level"], result["explanation"], result["transcript"])

    return {
        "id": analysis_id,
        "transcript": result["transcript"],
        "risk_level": result["risk_level"],
        "flags": result["flags"],
        "flagged_phrases": result["flagged_phrases"],
        "explanation": result["explanation"],
        "audio_url": audio_url
    }


# ---- Call history endpoint ----
@app.get("/call-analyses")
def get_call_analyses():
    db = SessionLocal()
    analyses = db.query(CallAnalysis).order_by(CallAnalysis.date_analyzed.desc()).all()
    db.close()
    return [
        {
            "id": a.id,
            "transcript": a.transcript,
            "risk_level": a.risk_level,
            "explanation": a.explanation,
            "date_analyzed": a.date_analyzed.isoformat(),
            "audio_url": a.audio_url
        }
        for a in analyses
    ]
