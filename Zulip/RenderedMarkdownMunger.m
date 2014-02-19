//
//  RenderedMarkdownMunger.m
//  Zulip
//
//  Created by Humbug on 8/8/13.
//
//

#import "RenderedMarkdownMunger.h"
#import "DTCoreText.h"

@implementation RenderedMarkdownMunger

+ (void)mungeThis:(RawMessage*)message {

    static NSDictionary *options;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        options = @{DTDefaultStyleSheet: [[DTCSSStylesheet alloc] initWithStyleBlock:@"pre {\n"
                                                                "    background-color: '#F5F5F5';\n"
                                                                ""
                                                                "}\n"
                                                                " .hll{background-color:#ffc}{background:#f8f8f8} .c{color:#408080;font-style:italic} .err{border:1px solid #f00} .k{color:#008000;font-weight:bold} .o{color:#666} .cm{color:#408080;font-style:italic} .cp{color:#bc7a00} .c1{color:#408080;font-style:italic} .cs{color:#408080;font-style:italic} .gd{color:#a00000} .ge{font-style:italic} .gr{color:#f00} .gh{color:#000080;font-weight:bold} .gi{color:#00a000} .go{color:#808080} .gp{color:#000080;font-weight:bold} .gs{font-weight:bold} .gu{color:#800080;font-weight:bold} .gt{color:#0040d0} .kc{color:#008000;font-weight:bold} .kd{color:#008000;font-weight:bold} .kn{color:#008000;font-weight:bold} span.kp{color:#008000} .kr{color:#008000;font-weight:bold} .kt{color:#b00040} .m{color:#666} .s{color:#ba2121} .na{color:#7d9029} .nb{color:#008000} .nc{color:#00f;font-weight:bold} .no{color:#800} .nd{color:#a2f} .ni{color:#999;font-weight:bold} .ne{color:#d2413a;font-weight:bold} .nf{color:#00f} .nl{color:#a0a000} .nn{color:#00f;font-weight:bold} .nt{color:#008000;font-weight:bold} .nv{color:#19177c} .ow{color:#a2f;font-weight:bold} .w{color:#bbb} .mf{color:#666} .mh{color:#666} .mi{color:#666} .mo{color:#666} .sb{color:#ba2121} .sc{color:#ba2121} .sd{color:#ba2121;font-style:italic} .s2{color:#ba2121} .se{color:#b62;font-weight:bold} .sh{color:#ba2121} .si{color:#b68;font-weight:bold} .sx{color:#008000} .sr{color:#b68} .s1{color:#ba2121} .ss{color:#19177c} .bp{color:#008000} .vc{color:#19177c} .vg{color:#19177c} .vi{color:#19177c} .il{color:#666}\n"
                                                                "blockquote {\n"
                                                                "    border-left-color: #dddddd;\n"
                                                                "    border-left-style: solid;\n"
                                                                "    border-left: 5px;\n"
                                                                "}"

                                                                "a {\n"
                                                                "    color: #0088cc\n"
                                                                "}"

                                                                "code {\n"
                                                                "    padding: 2px 4px;\n"
                                                                "    color: #d14;\n"
                                                                "    background-color: #F5F5F5;\n"
                                                                "    border: 1px solid #e1e1e8;\n"
                                                                "}\n"

                                                                "span.user-mention {\n"
                                                                "    padding: 2px 4px;\n"
                                                                "    background-color: #F2F2F2;\n"
                                                                "    border: 1px solid #e1e1e8;\n"
                                                                "}\n"

                                                                "img {\n"
                                                                "    max-height: 200px;\n"
                                                                "}\n"

                                                                "img.emoji {\n"
                                                                "height: 1.4em;\n"
                                                                "width: 1.4em;\n"
                                                                "}\n"],
                    DTDefaultFontFamily: @"Source Sans Pro",
                    DTDefaultFontSize: @"12pt"};
    });
    if (message.munged) {
        // Munging is an idempotent operation. Each StreamViewController attempts to munge when adding messages, and if the user has a
        // narrow loaded, two SVCs might each call mungeThis:. We only want to munge once.
        return;
    }
    // munge the message some
    //TODO: make this regex more robust, or make the build script make static/third/gemoji/images/emoji exist.
    message.content = [message.content stringByReplacingOccurrencesOfString:@"src=\"static/third/gemoji/images/emoji" withString:@"src=\"emoji"];
    NSData *data = [message.content dataUsingEncoding:NSUTF8StringEncoding];

    message.attributedString = [[NSAttributedString alloc] initWithHTMLData:data options:options documentAttributes:NULL];
    message.munged = YES;
}

@end
