#!/usr/bin/env python3
import sys
from pathlib import Path


def make_pdf(title: str, body: str) -> bytes:
    objects = []

    def add(obj: bytes) -> int:
        objects.append(obj)
        return len(objects)

    catalog_id = add(b"<< /Type /Catalog /Pages 2 0 R >>")
    pages_id = add(b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>")

    page_id = add(
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
        b"/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>"
    )

    stream = (
        f"BT /F1 24 Tf 72 720 Td ({title}) Tj ET\n"
        f"BT /F1 12 Tf 72 680 Td ({body}) Tj ET\n"
    ).encode("latin-1")
    contents_id = add(
        f"<< /Length {len(stream)} >>\nstream\n".encode("latin-1")
        + stream
        + b"endstream"
    )
    font_id = add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")

    assert catalog_id == 1 and pages_id == 2 and page_id == 3
    assert contents_id == 4 and font_id == 5

    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]
    for i, body_obj in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{i} 0 obj\n".encode("latin-1") + body_obj + b"\nendobj\n"

    xref_pos = len(out)
    out += f"xref\n0 {len(objects) + 1}\n".encode("latin-1")
    out += b"0000000000 65535 f \n"
    for off in offsets[1:]:
        out += f"{off:010d} 00000 n \n".encode("latin-1")

    out += (
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
        f"startxref\n{xref_pos}\n%%EOF\n"
    ).encode("latin-1")

    return bytes(out)


def main() -> int:
    pdf = make_pdf(
        title="ONLYOFFICE sample document",
        body="This PDF ships with the snap so the PDF editor has content to annotate.",
    )
    Path("samples/blank.pdf").write_bytes(pdf)
    print(f"wrote samples/blank.pdf ({len(pdf)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
