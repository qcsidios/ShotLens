# ShotLens 小红书商品详情页

## 交付内容

- `index.html`：全部商品图的可编辑 HTML 母版。
- `mobile-preview.html`：按手机商品页宽度检查缩略图和轮播图可读性。
- `index-v1.html`、`styles-v1.css`、`exports-v1/`：修改前的首版留档。
- `exports/00-square-cover.png`：1:1 商品主图，1500 × 1500。
- `exports/01`–`09`：3:4 商品轮播图，1500 × 2000。
- `exports/10-long-detail.png`：商品长详情页。

## 预览与重新导出

在 ShotLens 仓库中启动静态服务器：

```bash
python3 -m http.server 4311 --directory designs
```

然后进入本目录运行：

```bash
node export.mjs
```

页面不包含价格、微信或站外联系方式。默认限免、隐私边界、系统要求与翻译方向均使用有限定的准确表述。
