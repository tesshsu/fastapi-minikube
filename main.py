from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI on Minikube 🚀"}

@app.get("/ready")
async def readiness():
    return {"status": "ok"}

@app.get("/health")
async def health():
    return {"status": "ok"}

