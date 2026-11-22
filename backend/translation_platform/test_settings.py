from .settings import *

SECRET_KEY = 'test-only-secret-key'
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': ':memory:',
    }
}
