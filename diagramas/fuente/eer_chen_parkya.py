"""Genera el diagrama EER (notación de Chen) de ParkYa — versión Entrega 2.

Uso:  python diagramas/fuente/eer_chen_parkya.py
Salida: diagramas/eer-chen-parkya-entrega2.png

Los elementos en naranja son los que cambiaron frente a la Entrega 1
(ver docs/correcciones-entrega-1.md).
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse, Polygon, Rectangle, Circle

OUT = Path(__file__).resolve().parents[1] / "eer-chen-parkya-entrega2.png"

NAVY = "#1f3a56"
ATTR_FILL = "#eef3f8"
NEW = "#d9822b"      # cambios de la Entrega 2
CARD = "#8b1e1e"

EH = 4.6             # alto de entidad (el ancho depende del nombre)
RW, RH = 12, 8       # tamaño de rombo
AW, AH = 9.5, 3.2    # tamaño de atributo

# ---------------------------------------------------------------- modelo
# nombre: (x, y, débil, nuevo)
ENTIDADES = {
    "SEDE": (28, 112, False, False),
    "TARIFA": (60, 112, False, False),
    "TIPO_VEHICULO": (98, 112, False, False),
    "PLAN_SUSCRIPCION": (138, 112, False, False),
    "CLIENTE": (186, 104, False, False),
    "ESPACIO": (28, 70, True, False),
    "VEHICULO": (98, 74, False, False),
    "CLIENTE_OCASIONAL": (170, 68, False, False),
    "CLIENTE_SUSCRIPTOR": (206, 68, False, False),
    "SUSCRIPCION": (165, 42, False, False),
    "EMPLEADO": (14, 22, False, False),
    "SESION": (78, 36, False, False),
    "INCIDENCIA": (62, 4, False, False),
    "PAGO": (128, 10, False, False),
}

# entidad: [(atributo, dx, dy, tipo)]   tipo: key | partial | normal | new | newkey
ATRIBUTOS = {
    "SEDE": [("id_sede", 8, 9, "key"), ("nombre", 2, 13, "normal"),
             ("direccion", -9, 11, "normal"), ("ciudad", -17, 7, "normal")],
    "TARIFA": [("id_tarifa", 11, 9, "key"), ("valor_hora", 5, 16, "normal"),
               ("vigencia_desde", -5, 16, "normal"), ("vigencia_hasta", -13, 10, "normal")],
    "TIPO_VEHICULO": [("id_tipo_vehiculo", 9, 10, "key"), ("nombre", -3, 14, "normal")],
    "PLAN_SUSCRIPCION": [("id_plan", 13, 9, "key"), ("nombre", 5, 16, "normal"),
                         ("duracion_dias", -5, 16, "normal"), ("precio", -13, 10, "normal")],
    "CLIENTE": [("id_cliente", 14, -2, "key"), ("nombre", 17, 5, "normal"),
                ("documento", 9, 11, "normal"), ("telefono", -1, 15, "normal"),
                ("correo", -10, 11, "normal"), ("tipo_cliente", 14, -9, "new")],
    "CLIENTE_SUSCRIPTOR": [("fecha_afiliacion", 14, -7, "normal")],
    "ESPACIO": [("numero_espacio", -15, 6, "partial"), ("piso", -16, -2, "normal"),
                ("es_preferencial", -13, -9, "new"), ("estado", 0, -11, "new")],
    "VEHICULO": [("placa", -14, 4, "key")],
    "SUSCRIPCION": [("id_suscripcion", -14, -6, "key"), ("fecha_inicio", 16, -6, "normal"),
                    ("fecha_fin", 20, 1, "normal"), ("fecha_cancelacion", -1, -12, "new")],
    "EMPLEADO": [("id_empleado", 4, 10, "key"), ("nombre", -6, 7, "normal"),
                 ("documento", -6, -7, "normal"), ("cargo", 4, -10, "normal")],
    "SESION": [("id_sesion", -16, 6, "key"), ("hora_entrada", 17, 6, "normal"),
               ("hora_salida", 21, 0, "normal"), ("valor_cobrado", 19, -6, "normal")],
    "INCIDENCIA": [("id_incidencia", -15, -4, "key"), ("tipo_incidencia", 15, -4, "normal"),
                   ("descripcion", 17, 2, "normal"), ("fecha", -14, 3, "normal")],
    "PAGO": [("id_pago", -14, -4, "key"), ("monto", -4, -9, "normal"),
             ("metodo_pago", 9, -9, "normal"), ("fecha_pago", 17, -3, "normal")],
}

# nombre: (x, y, identificadora, nueva, [(entidad, cardinalidad, total)])
RELACIONES = {
    "DEFINE": (44, 112, False, False, [("SEDE", "1", False), ("TARIFA", "N", True)]),
    "APLICA": (79, 112, False, False, [("TARIFA", "N", True), ("TIPO_VEHICULO", "1", False)]),
    "CUBRE": (118, 112, False, False, [("TIPO_VEHICULO", "1", False), ("PLAN_SUSCRIPCION", "N", True)]),
    "TIENE": (28, 91, True, False, [("SEDE", "1", False), ("ESPACIO", "N", True)]),
    "ADMITE": (62, 88, False, True, [("TIPO_VEHICULO", "1", False), ("ESPACIO", "N", True)]),
    "CLASIFICA": (98, 93, False, False, [("TIPO_VEHICULO", "1", False), ("VEHICULO", "N", True)]),
    "POSEE": (132, 88, False, False, [("CLIENTE", "1", False), ("VEHICULO", "N", False)]),
    "SEGUN": (150, 80, False, False, [("PLAN_SUSCRIPCION", "1", False), ("SUSCRIPCION", "N", True)]),
    "CUBIERTA_POR": (128, 57, False, False, [("VEHICULO", "1", False), ("SUSCRIPCION", "N", True)]),
    "CONTRATA": (204, 50, False, False, [("CLIENTE_SUSCRIPTOR", "1", False), ("SUSCRIPCION", "N", True)]),
    "ALOJA": (50, 52, False, False, [("ESPACIO", "1", False), ("SESION", "N", True)]),
    "PROTAGONIZA": (90, 55, False, False, [("VEHICULO", "1", False), ("SESION", "N", True)]),
    "EMPLEA": (-4, 60, False, False, [("SEDE", "1", False), ("EMPLEADO", "N", True)]),
    "CIERRA": (44, 30, False, False, [("EMPLEADO", "1", False), ("SESION", "N", False)]),
    "GENERA\nINCIDENCIA": (72, 19, False, False, [("SESION", "1", False), ("INCIDENCIA", "N", False)]),
    "REPORTA": (34, 4, False, False, [("EMPLEADO", "1", False), ("INCIDENCIA", "N", True)]),
    "GENERA\nPAGO": (100, 14, False, True, [("SESION", "1", False), ("PAGO", "N", False)]),
    "PAGA": (145, 24, False, True, [("SUSCRIPCION", "1", False), ("PAGO", "N", False)]),
}

ESPECIALIZACION = {"padre": "CLIENTE", "circulo": (186, 84),
                   "hijos": ["CLIENTE_OCASIONAL", "CLIENTE_SUSCRIPTOR"],
                   "discriminador": "tipo_cliente"}


# ---------------------------------------------------------------- dibujo
def ancho(nombre):
    return max(11, len(nombre) * 0.95 + 2)


def borde(x, y, w, h, tx, ty):
    """Punto donde la recta (x,y)->(tx,ty) sale del rectángulo centrado en (x,y)."""
    dx, dy = tx - x, ty - y
    if dx == 0 and dy == 0:
        return x, y
    s = min((w / 2) / abs(dx) if dx else 1e9, (h / 2) / abs(dy) if dy else 1e9)
    return x + dx * s, y + dy * s


def linea(ax, p, q, doble=False, color="#333", lw=1.1, z=1):
    if not doble:
        ax.plot([p[0], q[0]], [p[1], q[1]], color=color, lw=lw, zorder=z)
        return
    dx, dy = q[0] - p[0], q[1] - p[1]
    n = (dx * dx + dy * dy) ** 0.5 or 1
    ox, oy = -dy / n * 0.35, dx / n * 0.35
    for k in (1, -1):
        ax.plot([p[0] + k * ox, q[0] + k * ox], [p[1] + k * oy, q[1] + k * oy],
                color=color, lw=lw, zorder=z)


def entidad(ax, nombre, x, y, debil, nueva):
    ec = NEW if nueva else NAVY
    EW = ancho(nombre)
    ax.add_patch(Rectangle((x - EW / 2, y - EH / 2), EW, EH, fc=NAVY, ec=ec, lw=2, zorder=3))
    if debil:
        ax.add_patch(Rectangle((x - EW / 2 - 0.6, y - EH / 2 - 0.6), EW + 1.2, EH + 1.2,
                               fc="none", ec=NAVY, lw=1.4, zorder=3))
    fs = 7
    ax.text(x, y, nombre, color="white", ha="center", va="center",
            fontsize=fs, fontweight="bold", zorder=4)


def atributo(ax, ex, ey, nombre, dx, dy, tipo):
    x, y = ex + dx, ey + dy
    ec = NEW if tipo in ("new", "newkey") else NAVY
    linea(ax, (ex, ey), (x, y), color="#555", lw=0.8)
    ax.add_patch(Ellipse((x, y), max(AW, len(nombre) * 0.6 + 2), AH, fc=ATTR_FILL, ec=ec, lw=1.6 if ec == NEW else 1, zorder=3))
    ax.text(x, y, nombre, ha="center", va="center", fontsize=5.6, zorder=4)
    ancho = len(nombre) * 0.52
    if tipo in ("key", "newkey"):
        ax.plot([x - ancho / 2, x + ancho / 2], [y - 0.8, y - 0.8], color="black", lw=0.8, zorder=4)
    elif tipo == "partial":
        ax.plot([x - ancho / 2, x + ancho / 2], [y - 0.8, y - 0.8], color="black", lw=0.8,
                ls=(0, (2, 1.5)), zorder=4)


def rombo(ax, x, y, w, h, **kw):
    return Polygon([(x, y + h / 2), (x + w / 2, y), (x, y - h / 2), (x - w / 2, y)],
                   closed=True, **kw)


def relacion(ax, nombre, x, y, identificadora, nueva, extremos):
    for ent, card, total in extremos:
        ex, ey = ENTIDADES[ent][:2]
        linea(ax, (ex, ey), (x, y), doble=total)
        bx, by = borde(ex, ey, ancho(ent) + 1.6, EH + 1.6, x, y)
        ax.text(bx, by, card, color=CARD, fontsize=6.5, fontweight="bold",
                ha="center", va="center", zorder=5,
                bbox=dict(fc="white", ec="none", pad=0.4))
    ec = NEW if nueva else NAVY
    ax.add_patch(rombo(ax, x, y, RW, RH, fc="white", ec=ec, lw=1.8 if nueva else 1.2, zorder=3))
    if identificadora:
        ax.add_patch(rombo(ax, x, y, RW - 2.2, RH - 1.6, fc="none", ec=ec, lw=1.2, zorder=3))
    ax.text(x, y, nombre, ha="center", va="center", fontsize=5.4,
            fontweight="bold", zorder=4, linespacing=1.1)


def especializacion(ax, esp):
    cx, cy = esp["circulo"]
    px, py = ENTIDADES[esp["padre"]][:2]
    linea(ax, (px, py), (cx, cy))               # parcial: línea simple
    ax.text((px + cx) / 2 - 1.2, (py + cy) / 2, esp["discriminador"], fontsize=5.6,
            color=NEW, ha="right", va="center", style="italic", zorder=5)
    for hijo in esp["hijos"]:
        hx, hy = ENTIDADES[hijo][:2]
        linea(ax, (cx, cy), (hx, hy))
    ax.add_patch(Circle((cx, cy), 2.2, fc="white", ec=NAVY, lw=1.2, zorder=3))
    ax.text(cx, cy, "d", fontsize=8, fontweight="bold", ha="center", va="center", zorder=4)


def leyenda(ax, x0, y0):
    w, h = 44, 50
    ax.add_patch(Rectangle((x0, y0), w, h, fc="white", ec="#666", lw=0.8, zorder=2))
    ax.text(x0 + w / 2, y0 + h - 2.5, "Notación (Chen / EER)", fontsize=7,
            fontweight="bold", ha="center", zorder=4)
    filas = [
        ("ent", "Entidad fuerte"), ("debil", "Entidad débil"), ("rel", "Relación"),
        ("relid", "Relación identificadora"), ("attr", "Atributo"), ("key", "Atributo clave (PK)"),
        ("partial", "Clave parcial (entidad débil)"), ("p", "Participación parcial"),
        ("t", "Participación total"), ("d", "Especialización disjunta y parcial"),
        ("new", "Nuevo o modificado en la Entrega 2"),
    ]
    for i, (k, txt) in enumerate(filas):
        y = y0 + h - 7 - i * 4.0
        sx = x0 + 7
        if k in ("ent", "debil"):
            ax.add_patch(Rectangle((sx - 3.5, y - 1.3), 7, 2.6, fc=NAVY, ec=NAVY, zorder=3))
            if k == "debil":
                ax.add_patch(Rectangle((sx - 4.1, y - 1.9), 8.2, 3.8, fc="none", ec=NAVY, zorder=3))
        elif k in ("rel", "relid"):
            ax.add_patch(rombo(ax, sx, y, 7, 3.4, fc="white", ec=NAVY, zorder=3))
            if k == "relid":
                ax.add_patch(rombo(ax, sx, y, 5, 2.2, fc="none", ec=NAVY, zorder=3))
        elif k in ("attr", "key", "partial"):
            ax.add_patch(Ellipse((sx, y), 7, 2.6, fc=ATTR_FILL, ec=NAVY, zorder=3))
            if k != "attr":
                ax.plot([sx - 2, sx + 2], [y - 0.6, y - 0.6], color="black", lw=0.8, zorder=4,
                        ls="-" if k == "key" else (0, (2, 1.5)))
        elif k == "p":
            linea(ax, (sx - 4, y), (sx + 4, y), z=4)
        elif k == "t":
            linea(ax, (sx - 4, y), (sx + 4, y), doble=True, z=4)
        elif k == "d":
            ax.add_patch(Circle((sx, y), 1.5, fc="white", ec=NAVY, zorder=3))
            ax.text(sx, y, "d", fontsize=6, fontweight="bold", ha="center", va="center", zorder=4)
        elif k == "new":
            ax.add_patch(Rectangle((sx - 3.5, y - 1.3), 7, 2.6, fc="white", ec=NEW, lw=2, zorder=3))
        ax.text(x0 + 14, y, txt, fontsize=6, va="center", zorder=4)


def main():
    fig, ax = plt.subplots(figsize=(22, 15.5))
    ax.set_xlim(-12, 230)
    ax.set_ylim(-22, 140)
    ax.set_aspect("equal")
    ax.axis("off")

    ax.text(107, 136, "ParkYa — Modelo Entidad-Relación Extendido (Notación de Chen)",
            fontsize=15, fontweight="bold", ha="center")
    ax.text(107, 132, "Base de Datos I — Versión Entrega 2 (con correcciones de la Entrega 1)",
            fontsize=9, ha="center", color="#444")

    for nombre, (x, y, ident, nueva, ext) in RELACIONES.items():
        relacion(ax, nombre, x, y, ident, nueva, ext)
    especializacion(ax, ESPECIALIZACION)
    for nombre, (x, y, debil, nueva) in ENTIDADES.items():
        entidad(ax, nombre, x, y, debil, nueva)
        for attr in ATRIBUTOS.get(nombre, []):
            atributo(ax, x, y, *attr)

    ax.text(128, -6, "Cada PAGO participa en exactamente una de GENERA PAGO o PAGA\n"
                     "(CHECK num_nonnulls(id_sesion, id_suscripcion) = 1)",
            fontsize=6, ha="center", va="top", color=NEW, style="italic")

    leyenda(ax, 180, -22)
    ax.text(-10, -20, "Integrantes: Jaime Granados · Camilo Badillo · Moisés Carrillo",
            fontsize=7, color="#444")

    fig.savefig(OUT, dpi=220, bbox_inches="tight", facecolor="white")
    print(f"Diagrama generado: {OUT}")


if __name__ == "__main__":
    main()
