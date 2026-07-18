import os
import google.generativeai as genai

genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

for m in genai.list_models():
    methods = getattr(m, "supported_generation_methods", None)
    if methods and "generateContent" in methods:
        print(m.name, "->", methods)
