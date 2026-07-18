# SentiCare: AI-Powered Scam Protection for the Elderly

SentiCare is a comprehensive safety solution designed to protect elderly individuals from phone scams and financial exploitation. By combining real-time phone state monitoring, AI-driven conversational analysis, and an automated family alert system, SentiCare provides a robust "Safety Net" against manipulation.

## 🚀 Key Features

- **Automated Call Screening:** Background monitoring of incoming calls with instant risk assessment via IPQualityScore.
- **AI Conversational Analysis:** Uses Google Gemini (Multimodal) to analyze call recordings for psychological manipulation, urgency, and impersonation.
- **Family Alert System:** Instant SMS (Twilio) and Email (SMTP) notifications sent to designated family members when high-risk activity is detected.
- **Accessibility First:** Features a high-contrast "Red Alert" UI and Text-to-Speech (TTS) warnings for users with visual or literacy challenges.
- **Safety History:** A centralized log of all analyzed calls for family review and audit.

---

## 🛠️ Technology Stack

- **Backend:** FastAPI (Python 3.11+), SQLAlchemy, PostgreSQL/SQLite.
- **AI/ML:** Google Gemini 1.5 Flash (Transcription & Reasoning).
- **Mobile:** Flutter (Dart) with background services.
- **Integrations:** 
  - **IPQualityScore:** Phone number reputation check.
  - **Cloudinary:** Secure storage for audio recordings.
  - **Twilio:** Automated SMS dispatch.
  - **SMTP:** Secure email alerts.

---

## 📋 Prerequisites

Before running the project, ensure you have the following installed:
- [Python 3.11+](https://www.python.org/downloads/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Git](https://git-scm.com/)

---

## ⚙️ Setup Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/harsh-15-2006/FIRST_API.git
cd FIRST_API
```

### 2. Backend Configuration
1. Create a virtual environment and install dependencies:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```
2. Create a `.env` file in the root directory and populate it with your API keys:
   ```env
   DATABASE_URL=your_database_url
   GEMINI_API_KEY=your_google_gemini_key
   IPQS_API_KEY=your_ipqualityscore_key
   CLOUDINARY_CLOUD_NAME=your_cloud_name
   CLOUDINARY_API_KEY=your_api_key
   CLOUDINARY_API_SECRET=your_api_secret
   TWILIO_ACCOUNT_SID=your_sid
   TWILIO_AUTH_TOKEN=your_token
   TWILIO_PHONE_NUMBER=your_twilio_number
   FAMILY_PHONE_NUMBER=recipient_number
   ALERT_EMAIL_ADDRESS=your_email
   ALERT_EMAIL_PASSWORD=your_app_password
   FAMILY_EMAIL=recipient_email
   ```
3. Start the server:
   ```bash
   uvicorn main:app --reload
   ```

### 3. Flutter App Configuration
1. Navigate to the app directory:
   ```bash
   cd scam_safety_app
   ```
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Update the API endpoints in `lib/analyze_call_screen.dart`, `lib/history_screen.dart`, and `lib/call_detection_service.dart` to point to your local or deployed backend URL.
4. Run the app on a physical Android device:
   ```bash
   flutter run
   ```

---

## 🔄 The 8-Step Safety Workflow

1. **Incoming Call:** The app detects an incoming call in the background.
2. **Risk Check:** The caller's number is instantly checked against the IPQualityScore database.
3. **Smart Popup:** If flagged, a popup appears: *"Suspicious number detected — switch to speaker so we can help protect you?"*
4. **Active Listening:** Upon user acceptance, the app enables the speaker and records the conversation.
5. **AI Analysis:** The audio is sent to Gemini 1.5 Flash for scam patterns.
6. **High-Risk Response:** If a scam is confirmed:
   - The screen turns **Red** with a clear warning.
   - A **Spoken Alert** tells the user: *"This looks like a scam — please end the call."*
   - **SMS + Email** are sent instantly to the family.
7. **Manual Termination:** The user ends the call safely.
8. **Report Logged:** A full report is saved to the **Safety History** for future review.

---

## 🤝 Contributing
Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
