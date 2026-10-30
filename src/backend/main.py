from app.main import create_app, application

if __name__ == "__main__":
    import os
    port = int(os.getenv("PORT", 80))
    application.run(host="0.0.0.0", port=port)
