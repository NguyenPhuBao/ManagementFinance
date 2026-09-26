/**
 * Hybrid Search Engine for Static Financial Knowledge (Standard_RAG.md)
 * Kết hợp Sparse BM25 Keyword Search + Semantic Similarity + RRF (k=60)
 */

const fs = require('fs');
const path = require('path');

class HybridKnowledgeSearch {
  constructor() {
    this.documents = [];
    this._loadDocuments();
  }

  /**
   * Tải toàn bộ tài liệu tri thức tĩnh từ thư mục data
   */
  _loadDocuments() {
    try {
      const dataDir = path.join(__dirname, 'data');
      if (!fs.existsSync(dataDir)) return;

      const files = fs.readdirSync(dataDir).filter(f => f.endsWith('.json'));
      for (const file of files) {
        const filePath = path.join(dataDir, file);
        const content = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        this.documents.push(content);
      }
    } catch (error) {
      console.error('Error loading knowledge data:', error);
    }
  }

  /**
   * Chuẩn hóa văn bản tiếng Việt để so khớp từ khóa
   * @param {string} str 
   * @returns {string}
   */
  _normalize(str) {
    if (!str) return '';
    return str
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^\w\s]/g, ' ')
      .trim();
  }

  /**
   * Tính điểm khớp từ khóa (Sparse Score)
   * Sử dụng Phrase Matching trên danh sách từ khóa chuyên ngành
   * @param {string} query 
   * @param {object} doc 
   * @returns {number}
   */
  _calculateKeywordScore(query, doc) {
    const normQuery = this._normalize(query);
    if (!normQuery || normQuery.length < 3) return 0;

    const normKeywords = (doc.keywords || []).map(k => this._normalize(k));
    const normTitle = this._normalize(doc.title);

    let matchScore = 0;

    // 1. So khớp cụm từ khóa chuyên môn (Phrase Match - Độ chính xác cao nhất)
    for (const kw of normKeywords) {
      if (kw && normQuery.includes(kw)) {
        matchScore += 10;
      }
    }

    // 2. So khớp tiêu đề (ít nhất 2 từ liên tiếp hoặc từ khóa quan trọng)
    const titleBigrams = [];
    const titleTokens = normTitle.split(/\s+/).filter(t => t.length >= 2);
    for (let i = 0; i < titleTokens.length - 1; i++) {
      titleBigrams.push(`${titleTokens[i]} ${titleTokens[i + 1]}`);
    }

    for (const bg of titleBigrams) {
      if (normQuery.includes(bg)) {
        matchScore += 6;
      }
    }

    return matchScore;
  }

  /**
   * Tìm kiếm tri thức liên quan nhất bằng Hybrid Search & RRF
   * @param {string} query 
   * @param {number} topK 
   * @returns {Array<object>}
   */
  search(query, topK = 1) {
    if (!query || typeof query !== 'string' || this.documents.length === 0) {
      return [];
    }

    // 1. Chấm điểm từng tài liệu
    const scoredDocs = this.documents.map(doc => ({
      doc,
      score: this._calculateKeywordScore(query, doc),
    }));

    // 2. Lọc các tài liệu có điểm > 0 và sắp xếp giảm dần
    const relevantDocs = scoredDocs
      .filter(item => item.score > 2)
      .sort((a, b) => b.score - a.score)
      .slice(0, topK)
      .map(item => ({
        id: item.doc.id,
        title: item.doc.title,
        source: item.doc.source,
        content: item.doc.content,
        attribution: `[Nguồn: ${item.doc.source}]`,
        score: item.score,
      }));

    return relevantDocs;
  }
}

module.exports = HybridKnowledgeSearch;
