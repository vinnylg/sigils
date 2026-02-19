import dash
from dash import dcc, html
from dash.dependencies import Input, Output
import plotly.express as px
import pandas as pd
import glob
import os
import json

# --- Configurações ---
# Ajuste o caminho se necessário. Assume que está rodando na raiz do 'sigils'
DATA_PATH = "data/netmon/results/*.jsonl"
REFRESH_INTERVAL_MS = 30 * 1000  # Atualiza a cada 30 segundos

app = dash.Dash(__name__, title="NetMon Dashboard")

# Layout Escuro (Dark Mode)
app.layout = html.Div(style={'backgroundColor': '#111111', 'color': '#FFFFFF', 'font-family': 'sans-serif', 'padding': '20px'}, children=[
    html.H1("NetMon - Network Observatory", style={'textAlign': 'center'}),
    
    html.Div([
        html.Span("Status: Monitorando... ", style={'color': '#00FF00'}),
        html.Span(id='last-update-text', style={'fontSize': '12px', 'color': '#888'})
    ], style={'textAlign': 'center', 'marginBottom': '20px'}),

    # Intervalo de atualização automática
    dcc.Interval(
        id='interval-component',
        interval=REFRESH_INTERVAL_MS,
        n_intervals=0
    ),

    # KPI Cards (Médias Gerais)
    html.Div(id='kpi-container', style={'display': 'flex', 'justifyContent': 'space-around', 'marginBottom': '20px'}),

    # Gráficos
    html.Div([
        html.Div([
            html.H3("Velocidade de Download (Mbps)"),
            dcc.Graph(id='download-graph')
        ], style={'width': '48%', 'display': 'inline-block'}),

        html.Div([
            html.H3("Velocidade de Upload (Mbps)"),
            dcc.Graph(id='upload-graph')
        ], style={'width': '48%', 'display': 'inline-block', 'float': 'right'}),
    ]),

    html.Div([
        html.H3("Latência / Ping (ms)"),
        dcc.Graph(id='ping-graph')
    ], style={'marginTop': '20px'}),

    html.Div([
        html.H3("Motivos de Retry / Falhas (Top 10)"),
        dcc.Graph(id='reasons-graph')
    ], style={'marginTop': '20px'})
])

# --- Função para carregar dados ---
def load_data():
    files = glob.glob(DATA_PATH)
    if not files:
        return pd.DataFrame()

    data_list = []
    for file in files:
        try:
            with open(file, 'r') as f:
                for line in f:
                    if line.strip():
                        try:
                            # Parse simples
                            entry = json.loads(line)
                            data_list.append(entry)
                        except json.JSONDecodeError:
                            pass
        except Exception:
            pass
    
    # O Pandas consegue "achatat" (normalize) o JSON aninhado
    df = pd.json_normalize(data_list)
    
    # Tratamento de datas
    if 'timestamp' in df.columns:
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df = df.sort_values('timestamp')
    
    return df

# --- Callbacks (Lógica de Atualização) ---
@app.callback(
    [Output('download-graph', 'figure'),
     Output('upload-graph', 'figure'),
     Output('ping-graph', 'figure'),
     Output('reasons-graph', 'figure'),
     Output('kpi-container', 'children'),
     Output('last-update-text', 'children')],
    [Input('interval-component', 'n_intervals')]
)
def update_metrics(n):
    df = load_data()
    
    if df.empty:
        empty_fig = px.line(title="Aguardando dados...")
        empty_fig.update_layout(template="plotly_dark", paper_bgcolor='#111111', plot_bgcolor='#111111')
        return empty_fig, empty_fig, empty_fig, empty_fig, "Sem dados", "Atualizado agora"

    # Filtra dados nulos ou zero se necessário, mas para gráfico de linha é bom ver os buracos
    
    # Configuração comum dos gráficos
    template = "plotly_dark"
    bg_color = '#111111'

    # 1. Gráfico de Download
    fig_down = px.line(df, x='timestamp', y='results.download_mbps', color='server.type',
                       title="Download por Tipo de Servidor", markers=True)
    fig_down.update_layout(template=template, paper_bgcolor=bg_color, plot_bgcolor=bg_color)

    # 2. Gráfico de Upload
    fig_up = px.line(df, x='timestamp', y='results.upload_mbps', color='server.type',
                     title="Upload por Tipo de Servidor", markers=True)
    fig_up.update_layout(template=template, paper_bgcolor=bg_color, plot_bgcolor=bg_color)

    # 3. Gráfico de Ping
    fig_ping = px.line(df, x='timestamp', y='results.ping_ms', color='server.type',
                       title="Latência (Ping)")
    fig_ping.update_layout(template=template, paper_bgcolor=bg_color, plot_bgcolor=bg_color)

    # 4. Gráfico de Retries (Reasons)
    # Filtra apenas onde houve retry reason
    if 'retry_reason' in df.columns:
        fail_df = df[df['retry_reason'].notna() & (df['retry_reason'] != '')]
        fail_counts = fail_df['retry_reason'].value_counts().reset_index()
        fail_counts.columns = ['Motivo', 'Contagem']
        
        fig_reasons = px.bar(fail_counts, x='Motivo', y='Contagem', color='Motivo',
                             title="Distribuição de Problemas")
        fig_reasons.update_layout(template=template, paper_bgcolor=bg_color, plot_bgcolor=bg_color)
    else:
        fig_reasons = px.bar(title="Sem registros de falhas")
        fig_reasons.update_layout(template=template, paper_bgcolor=bg_color, plot_bgcolor=bg_color)

    # 5. KPIs (Cards)
    last_run = df.iloc[-1]
    
    def make_card(title, value, unit, color):
        return html.Div([
            html.H4(title, style={'margin': '0', 'fontSize': '14px', 'color': '#AAA'}),
            html.H2(f"{value} {unit}", style={'margin': '5px 0', 'color': color})
        ], style={'backgroundColor': '#222', 'padding': '15px', 'borderRadius': '5px', 'width': '200px', 'textAlign': 'center'})

    kpis = [
        make_card("Último Download", round(last_run.get('results.download_mbps', 0), 1), "Mbps", "#00CCFF"),
        make_card("Último Upload", round(last_run.get('results.upload_mbps', 0), 1), "Mbps", "#00FF00"),
        make_card("Último Ping", round(last_run.get('results.ping_ms', 0), 1), "ms", "#FFCC00"),
        make_card("Total de Testes", len(df), "", "#FFFFFF")
    ]

    last_update = f"Última leitura: {last_run['timestamp']}"

    return fig_down, fig_up, fig_ping, fig_reasons, kpis, last_update

if __name__ == '__main__':
    # Roda o servidor. Acesse http://127.0.0.1:8050
    app.run(debug=True, host='0.0.0.0', port=8050)
