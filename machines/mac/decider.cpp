// Decider v11's plain state-first prompt and option-letter readout, using
// llama.cpp's native Metal backend. Matches decider.prompt.build (no shuffle)
// and engine_gguf._decode; never samples or generates an answer token.
#include <llama.h>
#include <nlohmann/json.hpp>
#include <cmath>
#include <iostream>
#include <string>
#include <vector>
using json = nlohmann::ordered_json;

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    llama_backend_init();
    auto mp = llama_model_default_params();
    mp.n_gpu_layers = 99;
    auto *model = llama_model_load_from_file(argv[1], mp);
    if (!model) return 2;
    auto cp = llama_context_default_params();
    cp.n_ctx = cp.n_batch = 8192;
    cp.n_ubatch = 2048;
    cp.n_seq_max = 1;
    auto *ctx = llama_init_from_model(model, cp);
    if (!ctx) return 2;
    const auto *vocab = llama_model_get_vocab(model);
    auto encode = [&](const std::string &s) {
        std::vector<llama_token> ids(s.size() + 16);
        int n = llama_tokenize(vocab, s.data(), s.size(), ids.data(), ids.size(), false, true);
        if (n < 0) { ids.resize(-n); n = llama_tokenize(vocab, s.data(), s.size(), ids.data(), ids.size(), false, true); }
        if (n < 0) throw std::runtime_error("tokenization failed");
        ids.resize(n); return ids;
    };
    std::vector<llama_token> labels;
    for (char a = 'A'; a <= 'Z'; ++a) {
        auto v = encode(std::string(1, a));
        if (v.size() == 1) labels.push_back(v[0]);
    }
    for (char a = 'A'; a <= 'Z' && labels.size() < 255; ++a)
        for (char b = 'A'; b <= 'Z' && labels.size() < 255; ++b) {
            auto v = encode(std::string{a, b});
            if (v.size() == 1) labels.push_back(v[0]);
        }
    if (labels.size() != 255) return 2;
    auto batch = llama_batch_init(8192, 0, 1);
    std::cout << "{\"ready\":true}" << std::endl;
    std::string line;
    while (std::getline(std::cin, line)) {
        try {
            const auto r = json::parse(line);
            const auto options = r.at("options").get<std::vector<std::string>>();
            if (options.size() < 2 || options.size() > 255) throw std::runtime_error("2..255 options required");
            std::vector<llama_token> ids = encode("Context:\n" + r.at("context").get<std::string>());
            auto append = [&](const std::string &s) { auto v = encode(s); ids.insert(ids.end(), v.begin(), v.end()); };
            std::string head = "\n\nQuestion: " + r.at("question").get<std::string>() + "\nOptions:";
            if (options.size() <= 10) {
                for (size_t i = 0; i < options.size(); ++i)
                    head += "\n(" + std::string(1, 'A' + i) + ") " + options[i];
                append(head + "\nAnswer: (");
            } else {
                append(head);
                for (size_t i = 0; i < options.size(); ++i) {
                    append("\n("); ids.push_back(labels[i]); append(") " + options[i]);
                }
                append("\nAnswer: (");
            }
            if (ids.size() > 8192) throw std::runtime_error("decision exceeds 8192 tokens; shorten the snapshot or candidates");
            llama_memory_clear(llama_get_memory(ctx), true);
            batch.n_tokens = ids.size();
            for (size_t i = 0; i < ids.size(); ++i) {
                batch.token[i] = ids[i]; batch.pos[i] = i;
                batch.n_seq_id[i] = 1; batch.seq_id[i][0] = 0;
                batch.logits[i] = i + 1 == ids.size();
            }
            // Exactly one decode of the complete prompt. No autoregressive loop.
            if (llama_decode(ctx, batch) != 0) throw std::runtime_error("llama_decode failed");
            const float *logits = llama_get_logits_ith(ctx, ids.size() - 1);
            double temperature = r.at("temperature");
            if (!std::isfinite(temperature) || temperature <= 0) throw std::runtime_error("invalid temperature");
            std::vector<double> probs;
            double largest = -INFINITY;
            for (size_t i = 0; i < options.size(); ++i) largest = std::max(largest, double(logits[labels[i]]) / temperature);
            double total = 0;
            for (size_t i = 0; i < options.size(); ++i) { probs.push_back(std::exp(logits[labels[i]] / temperature - largest)); total += probs.back(); }
            size_t best = 0;
            for (size_t i = 0; i < probs.size(); ++i) { probs[i] /= total; if (probs[i] > probs[best]) best = i; }
            std::cout << json{{"index", best}, {"probabilities", probs}, {"forward_passes", 1}, {"generated_tokens", 0}, {"prompt_tokens", ids.size()}}.dump() << std::endl;
        } catch (const std::exception &e) {
            std::cout << json{{"error", e.what()}}.dump() << std::endl;
        }
    }
    llama_batch_free(batch); llama_free(ctx); llama_model_free(model); llama_backend_free();
}
