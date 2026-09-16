# Kelly Frequency List Attribution

This repository contains frequency lists derived from the Kelly Project, developed by researchers at the University of Leeds and the University of Gothenburg.

## Citation

If you use this data in your research or work, please cite the original Kelly Project paper:

```bibtex
@article{kilgarriff2014corpus,
  title={Corpus-based vocabulary lists for language learners for nine languages},
  author={Kilgarriff, Adam and Charalabopoulou, Foteini and Gavrilidou, Maria and Johannessen, Lars Borin and Khalil, Sima and Kokkinakis, Dimitrios and Lew, Rachele and Sharoff, Serge and Vadlapudi, Ravikiran and Volodina, Elena},
  journal={Language Resources and Evaluation},
  volume={48},
  number={2},
  pages={121--163},
  year={2014},
  publisher={Springer},
  doi={https://doi.org/10.1015/lre-2014-0012}
}
```

## Source

- **Project**: Kelly Project - Kelly Lexical Lists
- **Institutions**: University of Leeds & University of Gothenburg
- **URL**: https://spraakbanken.gu.se/eng/kelly
- **DOI**: https://doi.org/10.1015/lre-2014-0012

## License

The Kelly Project frequency lists are made available for research and educational purposes. Please refer to the original Kelly Project terms and conditions for specific usage permissions.

## Data Format

The original Kelly Project provides frequency lists in Microsoft Excel (.xls) format with the following structure:

### English Format (en_m3.xls)
- **Columns**: ID, Word, POS, CEFR, Points
- **CEFR Levels**: A1, A2, B1, B2, C1, C2
- **Points**: Frequency indicator

### Russian Format (ru_m3.xls)
- **Columns**: Lemma, CEFR, POS, Frq abs, Frq ipm
- **CEFR Levels**: A1, A2, B1, B2, C1, C2
- **Frq ipm**: Instances per million (frequency measure)

## Processing

The JSON files in this repository were generated from the original Kelly Excel files using the `parse_kelly.rb` script in the `scripts/` directory.

### Processing Steps:
1. Parse Excel XLS files using the `roo` and `roo-xls` gems
2. Extract CEFR levels (handling Unicode fancy quotes U+201C and U+201D)
3. Create frequency tiers (top_50, top_200, top_1000) based on rank/ordering
4. Create CEFR-level tiers (a1, a2, b1, b2, c1, c2)
5. Generate Kotoshu-compatible JSON format with bonus scores

## Acknowledgments

We gratefully acknowledge the Kelly Project team for making their frequency lists available to the research community:

- Adam Kilgarriff (Lexical Computing Ltd)
- Foteini Charalabopoulou (Aristotle University of Thessaloniki)
- Maria Gavrilidou (ILSP / Athena R.C.)
- Lars Borin Johannessen (University of Gothenburg)
- Sima Khalil (University of Leeds)
- Dimitrios Kokkinakis (University of Gothenburg)
- Rachele Lew (Lexical Computing Ltd)
- Serge Sharoff (University of Leeds)
- Ravikiran Vadlapudi (University of Leeds)
- Elena Volodina (University of Gothenburg)

## Contact

For questions about the original Kelly Project data, please contact the Kelly Project team through their official channels at https://spraakbanken.gu.se/eng/kelly.

For questions about this processed data and the Kotoshu integration, please visit the Kotoshu project repository.
