"""
Celery worker module for DocsGPT.
This module initializes the Celery worker with the Flask application context.
"""

from application.celery_init import celery
from application.app import app

# Make Flask app context available to Celery tasks
celery.conf.update(app.config)


class ContextTask(celery.Task):
    """Celery task that runs within Flask application context"""

    def __call__(self, *args, **kwargs):
        with app.app_context():
            return self.run(*args, **kwargs)


celery.Task = ContextTask

if __name__ == "__main__":
    celery.start()
