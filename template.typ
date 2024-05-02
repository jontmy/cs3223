#let project(title: "", authors: (), body) = {
  set document(author: authors, title: title)
  set page(
    margin: (left: 10mm, right: 10mm, top: 9mm, bottom: 9mm),
    numbering: "1",
    number-align: center,
  )
  set text(lang: "en", size: 0.88em)

  // Set run-in subheadings, starting at level 3.
  set heading(numbering: "1.1.")
  show heading: it => {
    if it.level > 3 {
      parbreak()
      text(0.95em, style: "italic", weight: "regular", it.body + ".")
    } else {
      it
    }
  }

  // Set paragraph spacing.
  show par: set block(above: 0.9em, below: 0.9em)
  set par(leading: 0.58em, justify: true)
  show: columns.with(2, gutter: 1em)

  // Set table styles.
  set table(
    stroke: none,
    gutter: 0em,
    fill: (x, y) =>
      if x == 0 or y == 0 { rgb("#333333") },
    inset: (right: 01.5em),
  )

  show table.cell: it => {
    if it.x == 0 or it.y == 0 {
      set text(white)
      strong(it)
    } else {
      it
    }
  }
  
  body
}

