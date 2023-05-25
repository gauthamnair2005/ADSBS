<?xml version="1.0" encoding="ISO-8859-1"?>


<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">

  <xsl:key name="idds" match="sect1" use="sect1info/productname"/>

  <xsl:template name="detect-ds">
    <xsl:param name="package"/>
    <xsl:param name="dsbook"/>
    <xsl:choose>
      <xsl:when test="$package='gcc' or
                      $package='dbus' or
                      $package='vim' or
                      $package='systemd' or
                      $package='Python' or
                      $package='shadow'"/>
      <xsl:when test="$package='kernel'">true</xsl:when>
      <xsl:when test="$package='ds-Release'">true</xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="document($dsbook)">
          <xsl:copy-of select="boolean(key('idds',$package)/ancestor::chapter[@id='chapter-building-system'])"/>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="process-ds">
    <xsl:param name="package"/>
    <xsl:param name="dsbook"/>
    <xsl:choose>
      <xsl:when test="$package='gcc' or
                      $package='dbus' or
                      $package='vim' or
                      $package='systemd' or
                      $package='Python' or
                      $package='shadow'"/>
      <xsl:when test="$package='kernel'">
        <xsl:for-each select="document($dsbook)">
          <xsl:apply-templates select="key('idds',$package)[ancestor::chapter/@id='chapter-bootable']" mode="ds"/>
        </xsl:for-each>
      </xsl:when>
      <xsl:when test="$package='ds-Release'">
        <sect1 id="ds-Release">
          <xsl:apply-templates select="document($dsbook)//sect1[@id='ch-finish-theend']/*" mode="ds-remap"/>
        </sect1>
      </xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="document($dsbook)">
          <xsl:apply-templates select="key('idds',$package)[ancestor::chapter/@id='chapter-building-system']" mode="ds"/>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*" mode="ds">
    <xsl:choose>
<!--variablelist may contain id attributes equal to the name of the package,
    which generates non-unique id. They are of not much use (short descriptions)
    here. So just remove them-->
      <xsl:when test="self::variablelist"/>
<!--The id's in ds are of the form ch-xxx-package. We do not want to
    use that for file names and the like. So change the id-->
      <xsl:when test="self::sect1">
        <xsl:element name="sect1">
          <xsl:attribute name="id">
            <xsl:value-of select="./sect1info/productname"/>
          </xsl:attribute>
          <xsl:apply-templates mode="ds"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test=".//sect2">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="ds"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::sect2[@role='package']">
        <xsl:variable name="url" select="../sect1info/address/text()"/>
        <xsl:variable name="md5" select="//sect1[@id='materials-packages']//ulink[@url=$url]/../following-sibling::para/literal/text()"/>
        <xsl:variable name="patch">
          <xsl:call-template name="find-patch"/>
        </xsl:variable>
        <sect2 role="package">
          <xsl:copy-of select="./*"/>
          <bridgehead renderas="sect3">Package Information</bridgehead>
          <itemizedlist spacing="compact">
            <listitem>
              <para>
                Download (HTTP): <!--<xsl:element name="ulink">
                  <xsl:attribute name="url">
                    <xsl:value-of select="$url"/>
                  </xsl:attribute>
                </xsl:element>--><ulink url="{$url}"/>
              </para>
            </listitem>
            <listitem>
              <para>
                Download (FTP): <ulink url=" "/>
              </para>
            </listitem>
            <listitem>
              <para>
                Download MD5 sum: <xsl:value-of select="$md5"/>
              </para>
            </listitem>
          </itemizedlist>
          <xsl:if test="string-length($patch)&gt;10">
            <bridgehead renderas="sect3">Additional Downloads</bridgehead>
            <itemizedlist spacing="compact">
              <listitem>
                <para>
                  Required patch:
                  <ulink url="{$patch}"/>
                </para>
              </listitem>
            </itemizedlist>
          </xsl:if>
        </sect2>
      </xsl:when>
      <xsl:when test="self::sect2[@role='installation']">
        <sect2 role="installation">
          <xsl:apply-templates mode="ds-remap"/>
        </sect2>
      </xsl:when>
      <xsl:when test="self::sect2[@role='configuration']">
        <sect2 role="configuration">
          <xsl:apply-templates mode="ds-remap"/>
        </sect2>
      </xsl:when>
      <xsl:when test="self::sect2">
        <xsl:element name="sect2">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="ds"/>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>i<!--
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates/>
        </xsl:element>-->
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="find-patch">
    <xsl:variable name="patch-command" select="..//userinput[contains(string(),'patch -Np1')]/text()"/>
    <xsl:variable name="patch" select="substring-after($patch-command,'../')"/>
    <xsl:if test="string-length($patch) &gt; 10">
      <xsl:value-of select="//sect1[@id='materials-patches']//ulink/@url[contains(string(),$patch)]"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="*" mode="ds-remap">
    <xsl:choose>
      <xsl:when test=".//screen">
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="ds-remap"/>
        </xsl:element>
      </xsl:when>
      <xsl:when test="self::screen">
        <xsl:choose>
          <xsl:when test="@role='nodump'">
            <xsl:copy-of select="."/>
          </xsl:when>
<!-- Since we are using the *-full.xml files, revisions have already been
     selected, so no need to bother about revision attributes-->
          <xsl:when test="./userinput[@remap='install' or not(@remap)]">
            <screen role="root">
              <xsl:copy-of select="./*"/>
            </screen>
          </xsl:when>
          <xsl:when test="./userinput[@remap='test']">
            <para><command>
              <xsl:copy-of select="./userinput/text()"/>
            </command></para>
          </xsl:when>
          <xsl:otherwise>
            <xsl:copy-of select="."/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise><!--
        <xsl:copy-of select="."/>-->
        <xsl:element name="{name()}">
          <xsl:for-each select="attribute::*">
            <xsl:attribute name="{name()}">
              <xsl:value-of select="."/>
            </xsl:attribute>
          </xsl:for-each>
          <xsl:apply-templates mode="sect1"/>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
