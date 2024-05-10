import plotly.express as px
import plotly.graph_objects as go

config = {'displayModeBar': False}

data = dict(
    sends=[0, 0, 0, 1, 0, 1, 3, 12, 5, 4, 15, 18, 16, 17, 4, 2],
    grade=["5.12d", "5.12c", "5.12b", "5.12a", "5.11d",
           "5.11c", "5.11b", "5.11a", "5.10d", "5.10c",
           "5.10b", "5.10a", "5.9", "5.8", "5.7", "5.easy"])
fig = px.funnel(data, x='sends', y='grade')
fig.show(config=config)