from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "VisionApp Backend Running"}

@app.post("/detections")
async def upload_detection(detection: dict):
    # Temporarily skip saving to MongoDB, just return a confirmation message
    return {"message": "Received detection", "data": detection}

