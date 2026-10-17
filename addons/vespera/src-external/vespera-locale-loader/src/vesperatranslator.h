#pragma once

#include <QObject>
#include <QList>
#include <QTranslator>

class VesperaTranslator : public QObject
{
    Q_OBJECT

public:
    explicit VesperaTranslator(QObject *parent = nullptr);

public slots:
    bool loadLanguage(const QString &appName, const QString &langId);

private:
    bool loadTranslationFile(const QString &translationFilePath);

    QList<QTranslator *> m_translators;
};
