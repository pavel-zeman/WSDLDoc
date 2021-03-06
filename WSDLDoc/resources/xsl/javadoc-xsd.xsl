<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:ws="http://schemas.xmlsoap.org/wsdl/"
                xmlns:ws2="http://www.w3.org/ns/wsdl"
                xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/"
                xmlns:local="http://tomi.vanek.sk/xml/wsdl-viewer"
                version="1.0"
                exclude-result-prefixes="ws ws2 xsd soap local">

    <xsl:output method="html" encoding="utf-8" indent="yes"
               omit-xml-declaration="no" 
               media-type="text/html"
               doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
               doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>

    <xsl:strip-space elements="*"/>

    <xsl:param name="ELEMENT-NAME" />

<!-- Helper templates -->

<xsl:template name="LFsToBRs">
	<xsl:param name="input" />
	<xsl:choose>
		<xsl:when test="contains($input, '&#10;')">
			<xsl:value-of select="substring-before($input, '&#10;')" /><br />
			<xsl:call-template name="LFsToBRs">
				<xsl:with-param name="input" select="substring-after($input, '&#10;')" />
			</xsl:call-template>
		</xsl:when>
		<xsl:otherwise>
			<xsl:value-of select="$input" />
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>


<xsl:template name="strip-namespace">
    <xsl:param name="input"/>
    
    <xsl:choose>
        <xsl:when test="contains($input, ':')">
            <xsl:value-of select="substring-after($input, ':')"/>
        </xsl:when>
        <xsl:otherwise>
            <xsl:value-of select="$input"/>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template name="generate-documentation">
    <xsl:param name="input"/>

    <xsl:call-template name="LFsToBRs">
        <xsl:with-param name="input" select="$input"/>
    </xsl:call-template>
</xsl:template>


<xsl:template name="generate-type-name">
    <xsl:param name="input"/>

    <xsl:variable name="stripped-type">
        <xsl:call-template name="strip-namespace"><xsl:with-param name="input" select="$input"/></xsl:call-template>
    </xsl:variable>

    <xsl:choose>
        <xsl:when test="starts-with($input, 'xsd:')">
            <xsl:value-of select="$stripped-type"/>    
        </xsl:when>
        <xsl:otherwise>
            <a>
                <xsl:attribute name="href">
                    <xsl:value-of select="concat($stripped-type, '.html')"/>                                                        
                </xsl:attribute>
                <xsl:value-of select="$stripped-type"/>
            </a>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>

<xsl:template name="generate-type">
    <xsl:param name="input"/>
    
    <xsl:choose>
        <xsl:when test="@type">
            <xsl:call-template name="generate-type-name"><xsl:with-param name="input" select="@type"/></xsl:call-template>                        
        </xsl:when>
        <xsl:otherwise>
            <xsl:call-template name="generate-type-name"><xsl:with-param name="input" select="xsd:simpleType/xsd:restriction/@base"/></xsl:call-template>            
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>



<!-- Generates single attribute of a complex type. The input parameter can be either true (generating current type) or false (generating ancestor of current type) -->
<xsl:template name="generate-element">
    <xsl:param name="current-type"/>
    
    <tr>
        <!-- name -->
        <td>
            <xsl:choose>
                <xsl:when test="$current-type">
                    <xsl:value-of select="@name"/>
                </xsl:when>
                <xsl:otherwise>
                    <i>
                        (<xsl:value-of select="ancestor::xsd:complexType/@name"/>)
                        <xsl:value-of select="@name"/>
                    </i>                    
                </xsl:otherwise>
            </xsl:choose>
        </td>
        
        <!-- type -->
        <td>
            <xsl:call-template name="generate-type">
                <xsl:with-param name="input" select="."/>
            </xsl:call-template>
        </td>
        
        <!-- occurrence -->
        <td>
            <xsl:variable name="minValue">
                <xsl:choose>
                    <xsl:when test="@minOccurs"><xsl:value-of select="@minOccurs"/></xsl:when>
                    <xsl:otherwise>0</xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:variable name="maxValue">
                <xsl:choose>
                    <xsl:when test="@maxOccurs = 'unbounded'">*</xsl:when>
                    <xsl:when test="@maxOccurs"><xsl:value-of select="@maxOccurs"/></xsl:when>
                    <xsl:otherwise>*</xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:value-of select="concat($minValue, '..', $maxValue)"/>
        </td>
        
        <!-- restrictions -->
        <td>
            <xsl:choose>
                <xsl:when test="xsd:simpleType/xsd:restriction">
                    <xsl:for-each select="xsd:simpleType/xsd:restriction/*">
                        <xsl:value-of select="concat(substring-after(name(), ':'), '(', @value, ') ')"/>      
                    </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>&#160;</xsl:otherwise>
            </xsl:choose>
        </td>
        
        <!-- description -->
        <td>
            <xsl:call-template name="generate-documentation">
                <xsl:with-param name="input" select="xsd:annotation/xsd:documentation/text()"/>
            </xsl:call-template>
        </td>
    </tr>
</xsl:template>

<!-- each element of a complex type -->
<xsl:template match="xsd:element" mode="current-type">
    <xsl:call-template name="generate-element"><xsl:with-param name="current-type" select="true()"/></xsl:call-template>
</xsl:template>

<xsl:template match="xsd:element" mode="ancestor-type">
    <xsl:call-template name="generate-element"><xsl:with-param name="current-type" select="false()"/></xsl:call-template>
</xsl:template>






<!--
==================================================================
	Starting point
==================================================================
-->

<xsl:template match="/">
    <xsl:apply-templates select="/ws:definitions/ws:types/xsd:schema/xsd:complexType[@name = $ELEMENT-NAME] | /ws:definitions/ws:types/xsd:schema/xsd:simpleType[@name = $ELEMENT-NAME] "/>
</xsl:template>



<xsl:template match="xsd:complexType | xsd:simpleType">
	     <html>
		       <xsl:call-template name="render-head"/>
		       <xsl:call-template name="render-body"/>
	     </html>
</xsl:template>



   <!--
==================================================================
	Rendering: HTML head
==================================================================
-->

<xsl:template name="render-head">
    <head>
        <title><xsl:value-of select="@name"/></title>
        <meta http-equiv="content-type" content="text/html; charset=utf-8"/>
        <meta http-equiv="content-script-type" content="text/javascript"/>
        <meta http-equiv="content-style-type" content="text/css"/>
        <meta http-equiv="imagetoolbar" content="false"/>
        <meta name="MSSmartTagsPreventParsing" content="true"/>
        <link rel="stylesheet" type="text/css" href="stylesheet.css"/>
    </head>
</xsl:template>



<xsl:template name="render-body">
    <body>
        <xsl:choose>
            <xsl:when test="local-name() = 'complexType'">
                <xsl:call-template name="render-title-complex-type"/>
	              <xsl:call-template name="render-content-complex-type"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="render-title-simple-type"/>
	              <xsl:call-template name="render-content-simple-type"/>
            </xsl:otherwise>
        </xsl:choose>
	      <xsl:call-template name="render-footer"/>
    </body>
</xsl:template>


<xsl:template name="render-title-simple-type">
    <h1>Simple type <xsl:value-of select="@name"/></h1>
</xsl:template>

<xsl:template name="render-title-complex-type">
    <h1>Complex type <xsl:value-of select="@name"/></h1>
</xsl:template>

<xsl:template name="render-content-simple-type">
    <dl>
        <dt><b>Base type:</b></dt>
        <dd>
            <xsl:call-template name="generate-type-name">
                <xsl:with-param name="input" select="xsd:restriction/@base"/>
            </xsl:call-template>
        </dd>
        <dt><b>Restrictions:</b></dt>
        <xsl:for-each select="xsd:restriction/*[local-name() != 'enumeration']">
            <dd><xsl:value-of select="concat(substring-after(name(), ':'), '(', @value, ') ')"/></dd>
        </xsl:for-each>
        <xsl:if test="xsd:restriction/xsd:enumeration">
            <dd>
                Enumeration: 
                <xsl:for-each select="xsd:restriction/xsd:enumeration">
                    <xsl:value-of select="@value"/>
                    <xsl:if test="position() != last()">
                        <xsl:text>, </xsl:text>
                    </xsl:if>
                </xsl:for-each>
            </dd> 
        </xsl:if>
    </dl>
    
    <!-- Type description --> 
    <xsl:call-template name="generate-documentation">
        <xsl:with-param name="input" select="xsd:annotation/xsd:documentation/text()"/>
    </xsl:call-template>
</xsl:template>


<!-- generates table rows for a concrete type including its ancestors -->
<xsl:template name="generate-attributes-for-type">
    <xsl:param name="input"/>
    <xsl:param name="nested-level"/>
    
    <xsl:variable name="stripped-type">
        <xsl:call-template name="strip-namespace"><xsl:with-param name="input" select="$input//xsd:extension/@base"/></xsl:call-template>
    </xsl:variable>

    <xsl:if test="$input//xsd:extension">
        <xsl:call-template name="generate-attributes-for-type">
            <xsl:with-param name="input" select="//xsd:complexType[contains(@name, concat(':', $stripped-type))] | //xsd:complexType[@name = $stripped-type]"/>
            <xsl:with-param name="nested-level" select="$nested-level + 1"/>
        </xsl:call-template> 
    </xsl:if>
    
    <xsl:variable name="nested-elements" select="$input/xsd:sequence/* | $input/xsd:complexContent/xsd:extension/xsd:sequence/*"/>
    <xsl:choose>
        <xsl:when test="$nested-level = 0">
            <xsl:apply-templates select="$nested-elements" mode="current-type">
                <xsl:sort select="@name"/>
            </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
            <xsl:apply-templates select="$nested-elements" mode="ancestor-type">
                <xsl:sort select="@name"/>
            </xsl:apply-templates>
        </xsl:otherwise>
    </xsl:choose>
</xsl:template>


<xsl:template name="generate-extension-chain">
    <xsl:param name="input"/>
    <xsl:param name="first"/>

    <xsl:if test="$input//xsd:extension">
        <xsl:variable name="stripped-type">
            <xsl:call-template name="strip-namespace"><xsl:with-param name="input" select="$input//xsd:extension/@base"/></xsl:call-template>
        </xsl:variable>

        <xsl:call-template name="generate-extension-chain">
            <xsl:with-param name="input" select="//xsd:complexType[contains(@name, concat(':', $stripped-type))] | //xsd:complexType[@name = $stripped-type]"/>
            <xsl:with-param name="first" select="false()"/>
        </xsl:call-template>
    </xsl:if>
    
    <xsl:if test="not($first)">                
      <xsl:call-template name="generate-type-name">
          <xsl:with-param name="input" select="$input/@name"/>
      </xsl:call-template>
      <xsl:text> </xsl:text> 
    </xsl:if>    
</xsl:template>

<xsl:template name="render-content-complex-type">
    <dl>
        <xsl:if test=".//xsd:extension">
            <dt><b>Extends:</b></dt>
            <dd>
                <xsl:call-template name="generate-extension-chain">
                    <xsl:with-param name="input" select="."/>
                    <xsl:with-param name="first" select="true()"/>
                </xsl:call-template>
            </dd>
        </xsl:if>
        
        <xsl:variable name="current-name" select="@name"/>
        <xsl:variable name="extensions" select="//xsd:complexType[contains(xsd:complexContent/xsd:extension/@base, $current-name)]"/>
        <xsl:if test="$extensions">
            <dt><b>Extended by:</b></dt>
            <dd>
                <xsl:for-each select="$extensions">
                    <xsl:sort select="@name"/>
                    <xsl:call-template name="generate-type-name">
                        <xsl:with-param name="input" select="@name"/>
                    </xsl:call-template>
                    <xsl:text> </xsl:text> 
                </xsl:for-each>
            </dd>
        </xsl:if>
    </dl>
    
    <!-- Type description --> 
    <xsl:call-template name="generate-documentation">
        <xsl:with-param name="input" select="xsd:annotation/xsd:documentation/text()"/>
    </xsl:call-template>
    
    <!-- Attributes -->
    <br/>
    <br/>
    <table>
        <tr><th>Name</th><th>Type</th><th>Occurrence</th><th>Restrictions</th><th>Description</th></tr>
        <xsl:call-template name="generate-attributes-for-type">
            <xsl:with-param name="input" select="."/>
            <xsl:with-param name="nested-level" select="0"/>
        </xsl:call-template>
    </table>
 
 </xsl:template>



<xsl:template name="render-footer">
</xsl:template>


</xsl:stylesheet>