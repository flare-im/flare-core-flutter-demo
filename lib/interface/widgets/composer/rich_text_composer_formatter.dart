enum RichComposerInlineStyle { bold, italic, strike, inlineCode, link }

enum RichComposerBlockStyle {
  body,
  heading,
  quote,
  bulletList,
  orderedList,
  codeBlock,
}

final class RichComposerFormatting {
  const RichComposerFormatting({
    this.inlineStyles = const {},
    this.blockStyle = RichComposerBlockStyle.body,
  });

  final Set<RichComposerInlineStyle> inlineStyles;
  final RichComposerBlockStyle blockStyle;

  bool isInlineActive(RichComposerInlineStyle style) =>
      inlineStyles.contains(style);

  bool isBlockActive(RichComposerBlockStyle style) => blockStyle == style;

  RichComposerFormatting toggleInline(RichComposerInlineStyle style) {
    final next = {...inlineStyles};
    if (next.contains(style)) {
      next.remove(style);
    } else {
      next.add(style);
    }
    return RichComposerFormatting(
      inlineStyles: Set.unmodifiable(next),
      blockStyle: blockStyle,
    );
  }

  RichComposerFormatting toggleBlock(RichComposerBlockStyle style) {
    return RichComposerFormatting(
      inlineStyles: inlineStyles,
      blockStyle: blockStyle == style ? RichComposerBlockStyle.body : style,
    );
  }
}

abstract final class RichComposerMarkdownSerializer {
  static String serialize(String text, RichComposerFormatting formatting) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    final lines = trimmed.split('\n');
    var orderedIndex = 1;
    final output = <String>[];

    for (final line in lines) {
      final paragraph = line.trimRight();
      if (paragraph.trim().isEmpty) {
        output.add('');
        continue;
      }

      if (formatting.blockStyle == RichComposerBlockStyle.codeBlock) {
        output
          ..add('```')
          ..add(paragraph)
          ..add('```');
        continue;
      }

      final inline = _applyInlineStyles(paragraph, formatting.inlineStyles);
      switch (formatting.blockStyle) {
        case RichComposerBlockStyle.body:
          output.add(inline);
        case RichComposerBlockStyle.heading:
          output.add('## $inline');
        case RichComposerBlockStyle.quote:
          output.add('> $inline');
        case RichComposerBlockStyle.bulletList:
          output.add('- $inline');
        case RichComposerBlockStyle.orderedList:
          output.add('${orderedIndex++}. $inline');
        case RichComposerBlockStyle.codeBlock:
          break;
      }
    }

    return output.join('\n').trim();
  }

  static String _applyInlineStyles(
    String value,
    Set<RichComposerInlineStyle> styles,
  ) {
    if (value.isEmpty) return '';
    var output = value;

    if (styles.contains(RichComposerInlineStyle.link)) {
      output = '[$output](${_linkTarget(value)})';
    }
    if (styles.contains(RichComposerInlineStyle.inlineCode)) {
      output = '`$output`';
    }
    if (styles.contains(RichComposerInlineStyle.bold)) {
      output = '**$output**';
    }
    if (styles.contains(RichComposerInlineStyle.italic)) {
      output = '*$output*';
    }
    if (styles.contains(RichComposerInlineStyle.strike)) {
      output = '~~$output~~';
    }

    return output;
  }

  static String _linkTarget(String value) {
    final candidate = value.trim();
    if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
      return candidate;
    }
    return 'https://';
  }
}
