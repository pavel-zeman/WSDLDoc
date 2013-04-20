package cz;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;
import java.util.TooManyListenersException;

import javax.xml.XMLConstants;
import javax.xml.namespace.NamespaceContext;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathConstants;
import javax.xml.xpath.XPathExpression;
import javax.xml.xpath.XPathExpressionException;
import javax.xml.xpath.XPathFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;



public class WSDLDoc {

	private static final String WSDL_NAMESPACE = "http://schemas.xmlsoap.org/wsdl/";
	private static final String XSD_NAMESPACE = "http://www.w3.org/2001/XMLSchema";

	private HashSet<String> processedDocuments = new HashSet<String>();
	private TransformerFactory transformerFactory;
	private DocumentBuilder documentBuilder;
	private XPathExpression getTypesExpression;
	private Transformer wsdlTransformer;
	private Transformer xsdTransformer;
	private String destinationDirectory;
	private List<String> wsdlList = new ArrayList<String>();
	private Set<String> typeCollection = new HashSet<String>();
	private long generationStart;
	
	
	/**
	 * Simple constructor.
	 */
	public WSDLDoc(String destinationDirectory) {
		this.destinationDirectory = destinationDirectory;
		generationStart = System.currentTimeMillis();
	}

	/**
	 * Creates instance of document builder and XSLT transformers.
	 */
	public void setup() throws ParserConfigurationException, XPathExpressionException, TransformerConfigurationException {
		// create document builder
		DocumentBuilderFactory documentBuilderFactory = DocumentBuilderFactory.newInstance();
		documentBuilderFactory.setNamespaceAware(true);
		documentBuilder = documentBuilderFactory.newDocumentBuilder();
		
		// create transformer factory and parse XSLs
		transformerFactory = TransformerFactory.newInstance();
		wsdlTransformer = transformerFactory.newTransformer(new StreamSource(this.getClass().getResourceAsStream("/xsl/javadoc-wsdl.xsl")));
		xsdTransformer = transformerFactory.newTransformer(new StreamSource(this.getClass().getResourceAsStream("/xsl/javadoc-xsd.xsl")));
		
		// create XPath expression to get list of all complex types from WSDL
		XPathFactory xPathfactory = XPathFactory.newInstance();
		XPath xpath = xPathfactory.newXPath();
		NamespaceContext nsContext = new NamespaceContext() {
		    // returns URIs for prefixes 
			@Override
			public String getNamespaceURI(String prefix) {
		        if (prefix == null) {
		            throw new IllegalArgumentException("No prefix provided!");
		        } else if (prefix.equals("wsdl")) {
		            return WSDL_NAMESPACE;
		        } else if (prefix.equals("xsd")) {
		            return XSD_NAMESPACE;
		        } else {
		            return XMLConstants.NULL_NS_URI;
		        }
		    }

		    // this method is not used
		    @Override
		    public String getPrefix(String namespaceURI) {
		        return null;
		    }

		    // this method is not used
		    @Override
		    public Iterator<String> getPrefixes(String namespaceURI) {
		        return null;
		    }		
		};
		xpath.setNamespaceContext(nsContext);
		getTypesExpression = xpath.compile("/wsdl:definitions/wsdl:types/xsd:schema/xsd:complexType | /wsdl:definitions/wsdl:types/xsd:schema/xsd:simpleType");
	}

	/**
	 * Removes all files from the destination directory (currently it is not recursive).
	 */
	public void cleanDestinationDirectory() {
		File directory = new File(destinationDirectory);
		for (File file: directory.listFiles()) {
			file.delete();
		}
	}

	/**
	 * Loads all included or imported documents (based on the elementName parameter) and adds them to current document.
	 */
	private void resolveInnerDocuments(Document document, String basePath, String elementName) throws SAXException, IOException, ParserConfigurationException {
		// find all the import or include nodes and process each of them
		NodeList nodes = document.getElementsByTagNameNS(XSD_NAMESPACE, elementName);
		Node [] nodesToRemove = new Node[nodes.getLength()];
		
		for(int i=0;i<nodes.getLength();i++) {
			Node node = nodes.item(i);
			Node schemaLocationNode = node.getAttributes().getNamedItem("schemaLocation");

			// in some XSDs there are imports with no schemaLocation (it is probably bug, but the generator should not fail)
			if (schemaLocationNode != null) {
				String schemaLocation = schemaLocationNode.getNodeValue();
				Document innerDocument = getDocument(new File(basePath, schemaLocation));
				
				if (innerDocument != null) {
					NodeList childNodes = innerDocument.getDocumentElement().getChildNodes();
					for(int j=0;j<childNodes.getLength();j++) {
						Node newNode = childNodes.item(j);
						// only import element nodes (everything else is not important for the generation)
						if (newNode.getNodeType() == Node.ELEMENT_NODE) {
							node.getParentNode().appendChild(document.importNode(newNode, true));
						}
					}
				}
			}
			// the node itself should be removed (but we don't do it immediately not the break the iterator)
			nodesToRemove[i] = node;
		}
		for (Node node : nodesToRemove) {
			node.getParentNode().removeChild(node);
		}
	}
	
	/**
	 * Gets the DOM for the specified file and all included and imported XSDs.
	 * 
	 * @return Returns null, if the file was already processed and there is no need to process it again. 
	 * Otherwise, it returns its {@link Document}.
	 */
	private Document getDocument(File inputFile) throws SAXException, IOException, ParserConfigurationException {
		String canonicalPath = inputFile.getCanonicalPath();
		String basePath = inputFile.getCanonicalFile().getParent();
		
		// each file should be processed just once
		if (processedDocuments.contains(canonicalPath)) {
			return null;
		} else {
			processedDocuments.add(canonicalPath);
			
			// read the file itself
			Document document = documentBuilder.parse(inputFile);
			
			// recursively read all imports and includes
			resolveInnerDocuments(document, basePath, "import");
			resolveInnerDocuments(document, basePath, "include");
			return document;
		}
	}
	
	/**
	 * Generates documentation for a single WSDL files and all its types.
	 */
	private void generateWSDL(File inputFile) throws SAXException, IOException, ParserConfigurationException, TransformerException, XPathExpressionException {
		Document inputDocument = getDocument(inputFile);
		
		String fileName = inputFile.getName();
		String wsdlName = fileName.substring(0, fileName.lastIndexOf('.'));
		// add the WSDL to the global list so that at the end the list of all WSDLs can be generated
		wsdlList.add(wsdlName);
		
		System.out.println("Generating WSDL " + wsdlName);
		
		// generate WSDL documentation
		wsdlTransformer.transform(new DOMSource(inputDocument), new StreamResult(new File(destinationDirectory, wsdlName + ".html")));

		// generate XSD documentation for each type
		NodeList nodes = (NodeList) getTypesExpression.evaluate(inputDocument, XPathConstants.NODESET);
		for(int i=0;i<nodes.getLength();i++) {
			String typeName = nodes.item(i).getAttributes().getNamedItem("name").getNodeValue();
			// generate each type just once
			if (!typeCollection.contains(typeName)) {
				typeCollection.add(typeName);
				
				System.out.println("Generating type " + typeName);
				
				// run the transformation
				xsdTransformer.setParameter("ELEMENT-NAME", typeName);
				xsdTransformer.transform(new DOMSource(inputDocument), new StreamResult(new File(destinationDirectory, typeName + ".html")));
			}
		}
	}

	/**
	 * Generates documentation for all the WSDLs (all files with the wsdl extension) in the specified directory.
	 */
	public void generateWSDLs(String sourceDirectory) throws XPathExpressionException, SAXException, IOException, ParserConfigurationException, TransformerException {
		File directory = new File(sourceDirectory);
		// get all files in the specified directory with the wsdl extension ...
		File [] inputFiles = directory.listFiles(new FilenameFilter() {
			@Override
			public boolean accept(File dir, String name) {
				return name.endsWith(".wsdl");
			}
		});
		// ... and process each of them
		for (File inputFile : inputFiles) {
			generateWSDL(inputFile);
		}
	}

	
	/**
	 * Generates a simple XML containing list of all WSDLs, which is then processed using a stylesheet to create a "table of contents".
	 */
	public void generateWSDLList() throws TransformerException, IOException {
		// sort the list and create simple XML ...
		Collections.sort(wsdlList);
		StringBuilder wsdlListBuilder = new StringBuilder("<services>");
		for (String wsdl : wsdlList) {
			wsdlListBuilder.append("<service name=\"" + wsdl + "\"/>");
		}
		wsdlListBuilder.append("</services>");
		
		// ... and transform it into HTML
		ByteArrayInputStream bais = new ByteArrayInputStream(wsdlListBuilder.toString().getBytes("utf-8"));
		Transformer transformer = transformerFactory.newTransformer(new StreamSource(this.getClass().getResourceAsStream("/xsl/javadoc-all-wsdl.xsl")));
		transformer.transform(new StreamSource(bais), new StreamResult(new File(destinationDirectory, "overview-frame.html")));
		bais.close();
	}
	
	
	/**
	 * Generates a simple XML containing list of all types, which is then processed using a stylesheet to create a "table of contents".
	 */
	public void generateTypeList() throws TransformerException, IOException {
		// generate type list (the collection of types is a set and thus is not ordered, so it must be converted to a list and ordered) ...
		ArrayList<String> typeListInternal = new ArrayList<String>(typeCollection);
		Collections.sort(typeListInternal);
		
		StringBuilder typeListBuilder = new StringBuilder("<types>");
		for(String type : typeListInternal) {
			typeListBuilder.append("<type name=\"" + type + "\"/>");
		}
		typeListBuilder.append("</types>");
		
		// ... and transform it into HTML
		Transformer t = transformerFactory.newTransformer(new StreamSource(this.getClass().getResourceAsStream("/xsl/javadoc-all-xsd.xsl")));
		ByteArrayInputStream bais = new ByteArrayInputStream(typeListBuilder.toString().getBytes("utf-8"));
		t.transform(new StreamSource(bais), new StreamResult(new File(destinationDirectory, "all-types.html")));
		bais.close();
	}

	/**
	 * Copies single file from application to the destination directory (it is used for static content only).
	 */
	private void copyFile(String fileName) throws IOException {
		InputStream is = WSDLDoc.class.getResourceAsStream("/html/" + fileName);
		FileOutputStream fos = new FileOutputStream(new File(destinationDirectory, fileName));
		byte [] buffer = new byte[1024];
		int read;
		while ((read = is.read(buffer)) > 0) {
			fos.write(buffer,  0,  read);
		}
		fos.close();
		is.close();
	}

	/**
	 * Copies all required files to the destination directory.
	 */
	public void copyStaticFiles() throws IOException {
		copyFile("index.html");
		copyFile("default.html");
		copyFile("stylesheet.css");
	}

	/**
	 * Prints simple statistics about the generated documentation.
	 */
	public void printStatistics() {
		System.out.println("Generated " + wsdlList.size() + " WSDLs and " + typeCollection.size() + " types in " + (System.currentTimeMillis() - generationStart) + "ms");
	}
	
	public static void main(String[] args) throws TransformerException, IOException, TooManyListenersException, ParserConfigurationException, SAXException, XPathExpressionException {
		if (args.length < 2) {
			System.err.println("Usage: wsdldoc <source directory> <target directory>");
			return;
		}
		String destinationDirectory = args[1];
		String sourceDirectory = args[0];
		
		WSDLDoc instance = new WSDLDoc(destinationDirectory);
		instance.setup();
		instance.cleanDestinationDirectory();
		instance.generateWSDLs(sourceDirectory);
		instance.generateWSDLList();
		instance.generateTypeList();
		instance.copyStaticFiles();
		instance.printStatistics();
	}
}

