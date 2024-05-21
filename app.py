#!/usr/bin/env python

import plotly.express as px
import plotly.graph_objects as go
import dash
from dash import dcc, html, Input, Output
import pandas as pd
import base64
import io

# constant for grade/code conversion
GRADES = [{"value":1700, "label":"5.easy"}, {"value":1900, "label":"5.7"},
          {"value":2200, "label":"5.8"}, {"value":2500, "label":"5.9"},
          {"value":2800, "label":"5.10a"}, {"value":3100, "label":"5.10b"},
          {"value":3400, "label":"5.10c"}, {"value":4500, "label":"5.10d"},
          {"value":4800, "label":"5.11a"}, {"value":5100, "label":"5.11b"},
          {"value":5400, "label":"5.11c"}, {"value":6500, "label":"5.11d"},
          {"value":6800, "label":"5.12a"}, {"value":7100, "label":"5.12b"},
          {"value":7400, "label":"5.12c"}, {"value":8500, "label":"5.12d"},
          {"value":8800, "label":"5.13a"}, {"value":9100, "label":"5.13b"},
          {"value":9400, "label":"5.13c"}, {"value":10400, "label":"5.13d"}]

# Plotly configuration
config = {'displayModeBar': False}

# Create a Dash app
app = dash.Dash(__name__, external_stylesheets=['https://codepen.io/chriddyp/pen/bWLwgP.css'])

# Define the layout of the app
app.layout = html.Div([
    html.Div(children=['Upload your climbing ticks.csv to view your Route Pyramid!'],
             style={'fontSize': '18px'}),
    dcc.Upload(
        id='upload-data',
        children=html.Div(['Drag and Drop or ',html.A('Select Files')]),
        style={'width': '74vw',
               'height': '30px',
               'lineHeight': '30px',
               'borderWidth': '1px',
               'borderStyle': 'dashed',
               'borderRadius': '5px',
               'textAlign': 'center',
               'margin': '10px'},
               multiple=False),
    html.Div(children=['Route Filters'], style={'fontSize': '18px'}),
    dcc.Dropdown(['Sport', 'Trad', 'TR'], ['Sport'],
                multi=True, searchable=False, id='type-dropdown',
                style={'width': '75vw'}),
    dcc.Dropdown(['Onsight', 'Flash', 'Redpoint', 'Pinkpoint', 'Fell/Hung', 'N/A'],
                 ['Onsight', 'Flash', 'Redpoint'],
                 multi=True, searchable=False, id='send-dropdown',
                 style={'width':'75vw'}),
    dcc.Dropdown(list(range(2010, 2025)), list(range(2020, 2024)), 
                 multi=True, searchable=False, id='year-dropdown',
                 style={'width':'75vw'}),
    html.Div(children=['Max Grade:',
                       dcc.Dropdown(options=GRADES, value=8500, id='max-dropdown',
                                    searchable=False, clearable=False)],
            style={'width':'30vw'}),
    dcc.Checklist(['Include Multipitch Routes'],
                  ['Include Multipitch Routes'],
                  id='multi-filter'),
    dcc.Graph(id='graph-pyramid', config=config,
              style={'width':'80vw', 'height':'80vh'})
])

def parse_contents(contents, filename, criteria_type, criteria_send, criteria_year,
                   criteria_max, criteria_multi):
    _, content_string = contents.split(',')

    # Decode the base64 string & Read CSV
    decoded = io.StringIO(base64.b64decode(content_string).decode('utf-8'))
    ticks = pd.read_csv(decoded, parse_dates=['Date'])

    # Filter the dataframe based on criteria
    ticks = ticks.loc[ticks['Route Type'].isin(criteria_type), :]
    ticks = ticks.loc[ticks['Date'].dt.year.isin(criteria_year), :]
    if 'N/A' in criteria_send:
        ticks = ticks.loc[ticks['Lead Style'].isna() | ticks['Lead Style'].isin(criteria_send), :]
    else:
        ticks = ticks.loc[ticks['Lead Style'].isin(criteria_send), :]
    if criteria_multi == []:
        ticks = ticks.loc[ticks['Pitches']==1, :]
    ticks = ticks.loc[ticks['Rating Code'] <= criteria_max, :]

    # Calculate climbing pyramid metrics
    ticks['Grade'] = pd.cut(
        ticks['Rating Code'],
        bins=[0] + [item['value'] for item in GRADES if item['value'] <= criteria_max],
        labels=[item['label'] for item in GRADES if item['value'] <= criteria_max])
    counts = ticks.groupby('Grade', observed=False)['URL'].nunique().reset_index()
    counts.columns = ['Grade', 'Routes']
    counts.sort_values(by='Grade', ascending=False, inplace=True)

    # Create a chart based on the filtered dataframe
    fig = px.funnel(counts, x='Routes', y='Grade', title="User's Route Pyramid")

    return fig

@app.callback(
        Output('graph-pyramid', 'figure'),
        [Input('upload-data', 'contents'),
         Input('type-dropdown', "value"),
         Input('send-dropdown', "value"),
         Input('year-dropdown', "value"),
         Input('max-dropdown', "value"),
         Input('multi-filter', "value")],
         [dash.dependencies.State('upload-data', 'filename')])
def update_output(contents, criteria_type, criteria_send, criteria_year,
                 criteria_max, criteria_multi, filename):
    if contents is None:
        dummy = dict(
            Routes=[1, 0, 1, 0, 2, 3, 5, 8, 16, 32, 64, 80, 70, 90, 100, 120],
            Grade=["5.12d", "5.12c", "5.12b", "5.12a", "5.11d",
                   "5.11c", "5.11b", "5.11a", "5.10d", "5.10c",
                   "5.10b", "5.10a", "5.9", "5.8", "5.7", "5.easy"])
        return px.funnel(dummy, x='Routes', y='Grade', title="(Demo Data) Route Pyramid")
    else:
        fig = parse_contents(contents, filename, criteria_type, criteria_send, criteria_year,
                             criteria_max, criteria_multi)
        return fig

if __name__ == '__main__':
    app.run_server(debug=True)