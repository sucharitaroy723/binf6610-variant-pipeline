#!/usr/bin/env python3
"""Browse the week-9 run database: python3 dashboard/app.py runs.db [port]."""
import sqlite3
import sys
from contextlib import closing
from pathlib import Path
from urllib.parse import parse_qs, urlencode

import dash_ag_grid as dag
import pandas as pd
import plotly.graph_objects as go
from dash import Dash, Input, Output, State, ctx, dcc, html

if len(sys.argv) not in (2, 3):
    sys.exit("usage: python3 dashboard/app.py <database> [port]")
DB = Path(sys.argv[1]).resolve()
PORT = int(sys.argv[2]) if len(sys.argv) == 3 else 8050
Q1 = Path(__file__).resolve().parent.parent / "db" / "queries" / "q1.sql"
SITE_COLUMNS = ["chrom", "pos", "ref", "alt", "qual", "filter"]


def query(sql, params=()):
    """Open a read-only connection for each query, including callback threads."""
    with closing(sqlite3.connect(DB.as_uri() + "?mode=ro", uri=True)) as con:
        return pd.read_sql_query(sql, con, params=params)


def records(frame):
    # Keep missing metadata as JSON null rather than the string 'nan'.
    return frame.astype(object).where(pd.notna(frame), None).to_dict("records")


def grid(component_id, frame):
    return dag.AgGrid(
        id=component_id,
        rowData=records(frame),
        columnDefs=[{"field": c} for c in frame.columns],
        defaultColDef={"sortable": True, "filter": True, "resizable": True, "minWidth": 130},
        columnSize="sizeToFit",
        dashGridOptions={"pagination": True, "paginationPageSize": 25},
        style={"height": "390px", "width": "100%"},
    )


def sites_for(run_id):
    return query(
        "SELECT chrom, pos, ref, alt, qual, filter FROM variants "
        "WHERE run_id = ? ORDER BY chrom, pos, ref, alt", (run_id,)
    )


def variant_type(ref, alt):
    """Use the assignment's precedence: multiallelic, then SNP, then indel."""
    if "," in alt:
        return "multiallelic"
    return "SNP" if len(ref) == len(alt) == 1 else "indel"


def site_types(sites):
    return pd.Series([variant_type(r, a) for r, a in zip(sites["ref"], sites["alt"])],
                     index=sites.index, dtype=object)


def count_plot(values, title, x_title):
    counts = values.value_counts().sort_index()
    # Lists keep the figure's values easy to inspect as well as plot.
    figure = go.Figure(go.Bar(x=counts.index.tolist(), y=counts.tolist(),
                             marker_color="#176c80"))
    figure.update_layout(title=title, xaxis_title=x_title, yaxis_title="Number of sites",
                         template="plotly_white", clickmode="event+select")
    return figure


app = Dash(__name__, suppress_callback_exceptions=True, title="Variant-call results")
app.layout = html.Div([
    dcc.Location(id="url", refresh=False),
    html.Header([html.H1("Variant-call results"),
                 html.P("Explore pipeline runs, samples and variant calls.")]),
    html.Main(id="page-content"),
], style={"maxWidth": "1200px", "margin": "32px auto", "padding": "0 24px",
          "fontFamily": "Arial, sans-serif", "color": "#173442", "lineHeight": "1.5"})


@app.callback(Output("page-content", "children"),
              Input("url", "pathname"), Input("url", "search"))
def show_page(pathname, search):
    if pathname in ("/", None):
        runs = query(Q1.read_text())
        return [html.H2("Runs"),
                html.P("Choose a run to explore its results. Tables can be sorted and filtered."),
                html.Ul([html.Li(dcc.Link(str(run_id),
                                          href="/results?" + urlencode({"run": run_id})))
                         for run_id in runs["run_id"]]),
                grid("runs-table", runs)]
    back = dcc.Link("← All runs", href="/")
    if pathname != "/results":
        return [back, html.H2("Page not found")]
    run_id = parse_qs((search or "").lstrip("?")).get("run", [None])[0]
    if not run_id or query("SELECT run_id FROM runs WHERE run_id = ?", (run_id,)).empty:
        return [back, html.H2("Run not found"), html.P("Choose a run from the Runs page.")]

    sites = sites_for(run_id)
    samples = query(
        "SELECT rs.sample_id, rs.condition, s.phenotype, s.is_synthetic_phenotype "
        "FROM run_samples AS rs LEFT JOIN samples AS s ON s.sample_id = rs.sample_id "
        "WHERE rs.run_id = ? ORDER BY rs.sample_id", (run_id,)
    )
    quality = go.Figure(go.Histogram(x=sites["qual"].tolist(), marker_color="#176c80"))
    quality.update_layout(title="How confident are the calls?", xaxis_title="QUAL",
                          yaxis_title="Number of sites", template="plotly_white")
    return [
        back, html.H2(run_id), dcc.Store(id="selected-run", data=run_id),
        html.P(f"{len(samples):,} samples · {len(sites):,} variant sites"),
        html.H3("Samples"),
        html.P("Course phenotype labels are synthetic (made up), not clinical findings. "
               "Blank phenotype cells mean that sample has no phenotype metadata."),
        grid("samples-table", samples),
        dcc.Graph(id="plot-filter", figure=count_plot(
            sites["filter"], "How many sites passed, and why did the others fail?", "FILTER")),
        dcc.Graph(id="plot-qual", figure=quality),
        dcc.Graph(id="plot-type", figure=count_plot(
            site_types(sites), "How many SNPs, indels and multiallelic sites?", "Variant type")),
        html.H3("Variant sites"),
        html.P("Click a FILTER or variant-type bar to show its sites. "
               "The most recent click sets the selection; reset to show all sites."),
        html.Button("Show all sites", id="reset-sites", n_clicks=0),
        html.P(id="selection-summary", children=f"Showing all {len(sites):,} sites."),
        grid("sites-table", sites),
    ]


@app.callback(Output("sites-table", "rowData"), Output("selection-summary", "children"),
              Input("plot-filter", "clickData"), Input("plot-type", "clickData"),
              Input("reset-sites", "n_clicks"), State("selected-run", "data"))
def filter_sites(filter_click, type_click, reset_clicks, run_id):
    sites = sites_for(run_id)
    plot_id = ctx.triggered_id
    click = {"plot-filter": filter_click, "plot-type": type_click}.get(plot_id)
    if not click or not click.get("points"):
        return records(sites), f"Showing all {len(sites):,} sites."
    point = click["points"][0]
    category = point.get("label", point.get("x"))
    if category is None:
        return records(sites), f"Showing all {len(sites):,} sites."
    if plot_id == "plot-filter":
        selected = sites[sites["filter"] == category]
    else:
        selected = sites[site_types(sites).str.lower() == str(category).lower()]
    return records(selected), f"Showing {len(selected):,} sites: {category}."


if __name__ == "__main__":
    app.run(port=PORT, debug=False)
