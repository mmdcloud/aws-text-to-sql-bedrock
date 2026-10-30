from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

# Limiter is initialised without app here; init_app() is called in the factory.
# The key_func uses the remote address by default but the query blueprint
# overrides it per-endpoint to key on the authenticated Cognito sub (user ID).
limiter = Limiter(key_func=get_remote_address)

# db_pool is initialised lazily on first use via services/database.py
db_pool = None