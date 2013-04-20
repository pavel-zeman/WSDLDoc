<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:ws="http://schemas.xmlsoap.org/wsdl/"
                xmlns:ws2="http://www.w3.org/ns/wsdl"
                xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                version="1.0"
                exclude-result-prefixes="ws ws2 xsd soap">

   <xsl:output method="html" encoding="utf-8" indent="yes"
               omit-xml-declaration="no" 
               media-type="text/html"
               doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
               doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>

   <xsl:strip-space elements="*"/>



  <xsl:template match="/">
      <HTML>
          <HEAD>
              <link href="stylesheet.css" type="text/css" rel="stylesheet"/>
          </HEAD>
          <BODY>
              <h1>All services</h1>
              <xsl:for-each select="services/service">
                  <a target="detailFrame">
                      <xsl:attribute name="href">
                          <xsl:value-of select="concat(@name, '.html')"/>
                      </xsl:attribute>
                      <xsl:value-of select="@name"/>
                  </a>
                  <br/>
              </xsl:for-each>
          </BODY>
      </HTML>
  </xsl:template>
</xsl:stylesheet>