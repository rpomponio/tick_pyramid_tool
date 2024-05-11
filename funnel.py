#!/usr/bin/env python

import plotly.express as px
import plotly.graph_objects as go
import dash
from dash import dcc, html, Input, Output
import pandas as pd
import base64
import io

# Plotly configuration
config = {'displayModeBar': False}

data = dict(
    type=[0, 0, 0, 1, 0, 1, 3, 12, 5, 4, 15, 18, 16, 17, 4, 2],
    sends=[0, 0, 0, 1, 0, 1, 3, 12, 5, 4, 15, 18, 16, 17, 4, 2],
    grade=["5.12d", "5.12c", "5.12b", "5.12a", "5.11d",
           "5.11c", "5.11b", "5.11a", "5.10d", "5.10c",
           "5.10b", "5.10a", "5.9", "5.8", "5.7", "5.easy"])
fig = px.funnel(data, x='sends', y='grade')

# Create a Dash app
app = dash.Dash(__name__)

# Define the layout of the app
app.layout = html.Div([
    dcc.Upload(
        id='upload-data',
        children=html.Div(['Drag and Drop or ',html.A('Select Files')]),
        style={'width': '85vw',
               'height': '60px',
               'lineHeight': '60px',
               'borderWidth': '1px',
               'borderStyle': 'dashed',
               'borderRadius': '5px',
               'textAlign': 'center',
               'margin': '10px'}),
    html.Div(id='output-data-upload'),
    html.H3('Route Filters'),
    dcc.Dropdown(['Sport', 'Trad', 'Toprope'], 'Sport',
                searchable=False, id='type-dropdown',
                style={'width':'85vw'}),
    dcc.Dropdown(['Onsight', 'Flash', 'Redpoint', 'Pinkpoint', 'Fell/Hung'],
                 ['Onsight', 'Flash', 'Redpoint'],
                 multi=True, searchable=False, id='send-dropdown',
                 style={'width':'85vw'}),
    html.H3('Route Pyramid'),
    dcc.Graph(figure=fig, config=config,
            style={'width':'90vw', 'height':'90vh'})
    
])

def parse_contents(contents, filename, route_type):
    content_type, content_string = contents.split(',')

    # Decode the base64 string
    decoded = io.StringIO(base64.b64decode(content_string).decode('utf-8'))

    # Read the CSV
    ticks = pd.read_csv(decoded)

    # Parse file so that climbing Pyramid is calculable
    ticks['Grade'] = pd.cut(
        ticks['Rating Code'],
        bins=[0, 1700, 1900, 2200, 2500, 2800, 3100, 3400, 3700, 4800, 5100,
              5400, 5500, 6800, 7100, 7400, 7500],
        labels=["5.easy", "5.7", "5.8", "5.9", "5.10a", "5.10b", "5.10c", "5.10d",
                "5.11a", "5.11b", "5.11c", "5.11d", "5.12a", "5.12b", "5.12c", "5.12d"])
    ticks = ticks.loc[ticks['Route Type']==route_type, :]
    counts = ticks.groupby('Grade')['URL'].nunique()

    # Return the number of routes per grade
    return counts

@app.callback(Output('output-data-upload', 'children'),
              [Input('upload-data', 'contents'),
               Input('type-dropdown', 'route_type')],
              [dash.dependencies.State('upload-data', 'filename')])
def update_output(contents, filename, route_type):
    if contents is not None:
        children = parse_contents(contents, filename, route_type)
        return children

if __name__ == '__main__':
    app.run_server(debug=True)