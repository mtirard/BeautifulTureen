import javax.xml.parsers.*;
import javax.xml.xpath.*;
import org.w3c.dom.*;
import java.nio.file.*;
import java.util.*;

// Usage: java XPathOracle.java doc.xml queries.txt reps
// Prints one WL expression per query: {query, msPerEval, items} where items are
// {"e", tag, dataP} for elements, {"a", name, value} for attributes, {"t", text} for text,
// or {"s", stringValue} when the result is not a node set.
public class XPathOracle {
  static String q(String s) { return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""; }
  public static void main(String[] a) throws Exception {
    long t0 = System.nanoTime();
    DocumentBuilderFactory f = DocumentBuilderFactory.newInstance();
    f.setNamespaceAware(false);
    Document doc = f.newDocumentBuilder().parse(new java.io.File(a[0]));
    long t1 = System.nanoTime();
    System.out.println("{\"parse\", " + (t1 - t0) / 1e6 + "}");
    int reps = Integer.parseInt(a[2]);
    XPath xp = XPathFactory.newInstance().newXPath();
    for (String query : Files.readAllLines(Paths.get(a[1]))) {
      if (query.isBlank()) continue;
      StringBuilder sb = new StringBuilder();
      try {
        XPathExpression e = xp.compile(query);
        NodeList nl = null; String sv = null;
        long s = System.nanoTime();
        for (int r = 0; r < reps; r++) {
          try { nl = (NodeList) e.evaluate(doc, XPathConstants.NODESET); }
          catch (XPathExpressionException ex) { sv = e.evaluate(doc); }
        }
        double ms = (System.nanoTime() - s) / 1e6 / reps;
        sb.append("{").append(q(query)).append(", ").append(ms).append(", {");
        if (nl != null) {
          for (int i = 0; i < nl.getLength(); i++) {
            Node n = nl.item(i);
            if (i > 0) sb.append(", ");
            switch (n.getNodeType()) {
              case Node.ELEMENT_NODE: sb.append("{\"e\", ").append(q(n.getNodeName())).append(", ").append(((Element) n).getAttribute("data-p")).append("}"); break;
              case Node.ATTRIBUTE_NODE: sb.append("{\"a\", ").append(q(n.getNodeName())).append(", ").append(q(n.getNodeValue())).append("}"); break;
              case Node.TEXT_NODE: sb.append("{\"t\", ").append(q(n.getNodeValue())).append("}"); break;
              default: sb.append("{\"n\", ").append(n.getNodeType()).append("}");
            }
          }
        } else sb.append("{\"s\", ").append(q(sv)).append("}");
        sb.append("}}");
      } catch (Exception ex) {
        sb.setLength(0); sb.append("{").append(q(query)).append(", \"error\", ").append(q(ex.toString())).append("}");
      }
      System.out.println(sb);
    }
  }
}
