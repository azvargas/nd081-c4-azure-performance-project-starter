from flask import Flask, request, render_template
import os
import random
import redis
import socket
import sys
import logging
from datetime import datetime

# App Insights
#Logging
from opencensus.ext.azure.log_exporter import AzureLogHandler
from opencensus.ext.azure.log_exporter import AzureEventHandler
# Metrics
from opencensus.stats import stats as stats_module
from opencensus.trace import config_integration
from opencensus.ext.azure import metrics_exporter
# Tracer
from opencensus.ext.azure.trace_exporter import AzureExporter
from opencensus.trace.samplers import ProbabilitySampler
from opencensus.trace.tracer import Tracer
# Middleware
from opencensus.ext.flask.flask_middleware import FlaskMiddleware

connectionString = 'InstrumentationKey=67bac6b5-9598-41bf-981d-466a91f917db'

# Logging
config_integration.trace_integrations(['logging'])
config_integration.trace_integrations(['requests'])
logger = logging.getLogger(__name__)
handler = AzureLogHandler(connection_string = connectionString)
handler.setFormatter(logging.Formatter('%(traceId)s %(spanId)s %(message)s'))
logger.addHandler(handler)
logger.addHandler(AzureEventHandler(connection_string = connectionString))
logger.setLevel(logging.INFO)

# Metrics
stats = stats_module.stats
view_manager = stats.view_manager
exporter = metrics_exporter.new_metrics_exporter(
    enable_standard_metrics = True,
    connection_string = connectionString
)
view_manager.register_exporter(exporter)

# Tracing
tracer = Tracer(
    exporter = AzureExporter(connection_string = connectionString),
    sampler = ProbabilitySampler(1.0)
)

app = Flask(__name__)

# Requests
middleware = FlaskMiddleware(
    app = app,
    exporter = AzureExporter(connection_string = connectionString),
    sampler = ProbabilitySampler(1.0)
)

# Load configurations from environment or config file
app.config.from_pyfile('config_file.cfg')

if ("VOTE1VALUE" in os.environ and os.environ['VOTE1VALUE']):
    button1 = os.environ['VOTE1VALUE']
else:
    button1 = app.config['VOTE1VALUE']

if ("VOTE2VALUE" in os.environ and os.environ['VOTE2VALUE']):
    button2 = os.environ['VOTE2VALUE']
else:
    button2 = app.config['VOTE2VALUE']

if ("TITLE" in os.environ and os.environ['TITLE']):
    title = os.environ['TITLE']
else:
    title = app.config['TITLE']

redis_server = os.environ['REDIS']

# Redis Connection to another container
try:
    if "REDIS_PWD" in os.environ:
        r = redis.StrictRedis(host=redis_server, port=6379, password=os.environ['REDIS_PWD'])
    else:
        r = redis.Redis(redis_server)
    r.ping()
except redis.ConnectionError:
    exit('Failed to connect to Redis, terminating.')

# Change title to host name to demo NLB
if app.config['SHOWHOST'] == "true":
    title = socket.gethostname()

# Init Redis
if not r.get(button1): r.set(button1,0)
if not r.get(button2): r.set(button2,0)

@app.route('/', methods=['GET', 'POST'])
def index():

    if request.method == 'GET':

        # Get current values
        vote1 = r.get(button1).decode('utf-8')
        # use tracer object to trace cat vote
        with tracer.span(name = 'Cats Vote') as span:
            print('Cats Vote')

        vote2 = r.get(button2).decode('utf-8')
        # use tracer object to trace dog vote
        with tracer.span(name = 'Dogs Vote') as span:
            print('Dogs Vote')

        # Return index with values
        return render_template("index.html", value1=int(vote1), value2=int(vote2), button1=button1, button2=button2, title=title)

    elif request.method == 'POST':

        if request.form['vote'] == 'reset':

            #Return results
            
            vote1 = r.get(button1).decode('utf-8')
            properties = {'custom_dimensions': {'Cats Vote': vote1}}
            # use logger object to log cat vote
            logger.info('Cats Vote', extra=properties)

            vote2 = r.get(button2).decode('utf-8')
            properties = {'custom_dimensions': {'Dogs Vote': vote2}}
            # use logger object to log dog vote
            logger.info('Dogs Vote', extra=properties)

            # Empty table
            r.set(button1,0)
            r.set(button2,0)

            return render_template("index.html", value1=int(vote1), value2=int(vote2), button1=button1, button2=button2, title=title)

        else:

            # Insert vote result into DB
            vote = request.form['vote']
            r.incr(vote,1)

            # Get current values
            vote1 = r.get(button1).decode('utf-8')
            vote2 = r.get(button2).decode('utf-8')

            # Return results
            return render_template("index.html", value1=int(vote1), value2=int(vote2), button1=button1, button2=button2, title=title)

if __name__ == "__main__":
    # TODO: Use the statement below when running locally
    # app.run() 
    # TODO: Use the statement below before deployment to VMSS
    app.run(host='0.0.0.0', threaded=True, debug=True) # remote
